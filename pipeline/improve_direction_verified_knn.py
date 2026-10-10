"""Reproducible retrospective, group-separated kNN development experiment.

No app assets, gold labels, frozen releases or historical reports are modified.
Run from repo root: .venv/Scripts/python pipeline/improve_direction_verified_knn.py
"""
import csv
import hashlib
import html
import itertools
import inspect
import json
import pickle
import re
import zipfile
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

import cv2
import numpy as np
from sklearn.metrics import cohen_kappa_score
from sklearn.model_selection import GroupKFold, GroupShuffleSplit
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from threadpoolctl import threadpool_limits

# Small low-dimensional kNN fits are faster and reproducible with one BLAS thread.
_THREAD_LIMIT = threadpool_limits(limits=1)

from audit_abnormal_detection import RULES, metrics, write_csv
from freeze_production_semiquant import _make_model
from markerless_strip import (MarkerlessStripConfig, extract_markerless_features,
                             _mean_hsv, _mean_lab, _normalize_features)
from model_features import hsv_to_circular_features
from semiquant_schema import ANALYTE_ORDER
from specimen_grouping import specimen_group
from vision_pipeline import feature_columns_for_analyte

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / 'pipeline/output/orientation_audit_2026-10-11_v3'
OUT = ROOT / 'pipeline/output/knn_improvement_2026-10-11'
FRACTIONS = (1., .75, .5)
VARIANTS = [(awb, fraction, space) for awb in (True, False)
            for fraction in FRACTIONS for space in ('normalized_hsv', 'hsv', 'lab')]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_json(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2, allow_nan=False) + '\n', encoding='utf-8')


def crop_bounds(roi, fraction, dx=0, dy=0):
    x, y, w, h = roi
    size = max(2, int(round(min(w, h) * fraction)))
    x0 = min(x + w - size, max(x, x + (w-size)//2 + dx))
    y0 = min(y + h - size, max(y, y + (h-size)//2 + dy))
    return x0, y0, size, size


def load_image(row):
    event, source = row['event_id'], row['source_zip']
    if source.startswith('LAUAAN'):
        m = re.fullmatch(r'LAUAAN-P(\d+)-L(\d+)', event)
        light = {'4000':'Cool', '2700':'Warm', '5500':'Daylight'}[m[2]]
        folder = ROOT / 'new_uritect_dataset/uritect_2026-7-30_Laua-an/_extracted/uritect_2026-7-30_Laua-an_RHU' / str(int(m[1]))
        path = next(p for p in folder.glob('*') if light.lower() in p.name.lower())
        data = path.read_bytes()
    else:
        m = re.search(r'_([^_]+)_(Cool|Warm|Daylight)$', event)
        package = next((ROOT / 'pipeline/dataset/cabatuan_cleaned').rglob(source))
        with zipfile.ZipFile(package) as archive:
            wanted = f'images/{m[1]}/{m[1]}-{m[2]}.jpg'
            data = archive.read(next(n for n in archive.namelist() if n.lower() == wanted.lower()))
    image = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
    h, w = image.shape[:2]
    if max(h, w) > 1100:
        image = cv2.resize(image, (round(w*1100/max(h,w)), round(h*1100/max(h,w))), interpolation=cv2.INTER_AREA)
    return image, hashlib.sha256(data).hexdigest()


def extract_event(item):
    index, row, evidence = item
    image, image_hash = load_image(row)
    rotations = {'rot90_cw':cv2.ROTATE_90_CLOCKWISE, 'rot180':cv2.ROTATE_180,
                 'rot90_ccw':cv2.ROTATE_90_COUNTERCLOCKWISE}
    orientation = evidence['orientation']
    if orientation != 'exif':
        image = cv2.rotate(image, rotations[orientation])
    result = extract_markerless_features(image, orientation=orientation,
                                        config=MarkerlessStripConfig(feature_space='normalized_hsv'))
    old = np.array([[evidence['features'][c] for c in feature_columns_for_analyte(a, feature_space='normalized_hsv')]
                    for a in ANALYTE_ORDER])
    actual = np.array([result.features_by_pad[a] for a in ANALYTE_ORDER])
    if not np.allclose(old, actual, atol=1e-5, rtol=0):
        raise ValueError(f'Baseline extraction drift: {row["event_id"]}')
    corrected = np.clip(image.astype(np.float32) * np.array(result.awb_gains_bgr).reshape(1,1,3), 0, 255).astype(np.uint8)
    features, augmentations = [], []
    for awb, fraction, space in VARIANTS:
        source = corrected if awb else image
        variants = []
        # Neutral exposure perturbation and conservative central-crop jitter.
        # The caller indexes these ONLY with the training partition.
        for brightness, dx, dy in ((1.,0,0),(.97,0,0),(1.03,0,0),(1.,-1,-1),(1.,1,1)):
            values = {}
            for analyte in ANALYTE_ORDER:
                x,y,w,h = crop_bounds(result.pad_rois[analyte], fraction, dx, dy)
                patch = source[y:y+h,x:x+w]
                if brightness != 1:
                    # Skip clipped perturbations; retain the unmodified crop.
                    changed = patch.astype(np.float32) * brightness
                    if np.max(changed) <= 255:
                        patch = np.rint(changed).astype(np.uint8)
                values[analyte] = _mean_lab(patch) if space == 'lab' else _mean_hsv(patch)
            if space == 'normalized_hsv':
                values = _normalize_features(values)
            variants.append([values[a] for a in ANALYTE_ORDER])
        features.append(variants[0])
        augmentations.append(variants[1:])
    folder = OUT / 'image_evidence'
    context = image.copy()
    for a in ANALYTE_ORDER:
        x,y,w,h = result.pad_rois[a]
        cv2.rectangle(context,(x,y),(x+w,y+h),(0,180,180),1)
        cv2.putText(context,a,(x+w+3,y+h),cv2.FONT_HERSHEY_SIMPLEX,.32,(0,80,150),1)
        cv2.imwrite(str(folder / f'{index:04d}_{ANALYTE_ORDER.index(a):02d}.jpg'),image[y:y+h,x:x+w])
    xs = [r[0] for r in result.pad_rois.values()]; ys = [r[1] for r in result.pad_rois.values()]
    right = max(r[0]+r[2] for r in result.pad_rois.values())
    bottom = max(r[1]+r[3] for r in result.pad_rois.values())
    cv2.imwrite(str(folder / f'{index:04d}_context.jpg'),context[max(0,min(ys)-40):min(image.shape[0],bottom+90),max(0,min(xs)-60):min(image.shape[1],right+170)])
    return index, np.array(features), np.array(augmentations), dict(event_id=row['event_id'], image_sha256=image_hash,
                orientation=orientation, rois=result.pad_rois, awb_gains=result.awb_gains_bgr,
                context=f'image_evidence/{index:04d}_context.jpg')


def measure(truth, pred, groups, analyte, intervals=False):
    value = metrics(truth.tolist(), pred.tolist(), groups.tolist(), analyte, intervals)
    classes = value['class_metrics'].values()
    for field in ('sensitivity','specificity'):
        defined = [x[field] for x in classes if x[field] is not None]
        value['macro_'+field] = float(np.mean(defined)) if defined else None
    value['cohens_kappa'] = float(cohen_kappa_score(truth,pred)) if len(set(truth)|set(pred)) > 1 else None
    return value


def objective(value):
    # Predeclared exploratory ranking, NOT a clinical acceptance threshold.
    rules = value['reference_label_thresholds'].values()
    balanced = [(r['sensitivity']+r['specificity'])/2 for r in rules
                if r['sensitivity'] is not None and r['specificity'] is not None]
    base = .65*value['macro_f1_supported_reference_classes'] + .35*value['macro_sensitivity']
    return .8*base + .2*float(np.mean(balanced)) if balanced else base


def inputs(features, config):
    x = features[config['variant']]
    if VARIANTS[config['variant']][2] != 'lab':
        return hsv_to_circular_features(x)
    return x


def fit_predict(features, augmented, truth, train, validation, config):
    # No validation/test pixel or label enters scaling, fitting or augmentation.
    if 'legacy_params' in config:
        params = config['legacy_params']
        x = features[0]
        model = _make_model(min(params['best_k'],len(train)),params['best_metric'],params.get('feature_transform','raw'))
        model.fit(x[train],truth[train])
        probs = model.predict_proba(x[validation])
        return model.classes_[probs.argmax(axis=1)], probs.max(axis=1), model
    x = inputs(features, config)
    tx, ty = x[train], truth[train]
    if config.get('augmentation'):
        extra_rows, extra_labels = [], []
        space = VARIANTS[config['variant']][2]
        for i in train:
            original = features[config['variant'],i]
            seen = {tuple(original)}
            for j,changed in enumerate(augmented[config['variant'],i]):
                if space == 'lab':
                    bounds = np.array([4.,2.,2.]) if j < 2 else np.array([8.,8.,8.])
                    delta = np.abs(changed-original)
                else:
                    delta = np.abs(changed-original)
                    delta[0] = min(delta[0],360-delta[0])
                    bounds = np.array([5.,.05,.06]) if j < 2 else np.array([15.,.12,.12])
                # Engineering color bounds do not independently verify labels.
                # Skip unstable colors and exact repeats of this source crop.
                key = tuple(changed)
                if np.all(np.isfinite(changed)) and np.all(delta <= bounds) and key not in seen:
                    seen.add(key); extra_rows.append(changed); extra_labels.append(truth[i])
        extra = np.array(extra_rows,dtype=float).reshape(-1,3)
        if VARIANTS[config['variant']][2] != 'lab':
            extra = hsv_to_circular_features(extra)
        tx = np.concatenate([tx,extra]); ty = np.concatenate([ty,np.array(extra_labels,dtype=truth.dtype)])
    knn = KNeighborsClassifier(n_neighbors=min(config['k'],len(tx)),metric=config['metric'],
                              weights=config['weights'],algorithm='kd_tree',n_jobs=1)
    model = make_pipeline(StandardScaler(), knn) if config['scale'] else knn
    model.fit(tx,ty)
    probs = model.predict_proba(x[validation])
    if config.get('balanced_votes'):
        counts = np.array([sum(ty == c) for c in model.classes_])
        probs /= np.sqrt(counts)
        probs /= probs.sum(axis=1,keepdims=True)
    return model.classes_[probs.argmax(axis=1)], probs.max(axis=1), model


def cross_validate(features, augmented, truth, folds, config):
    predictions = np.empty(len(truth),dtype=object); confidence = np.zeros(len(truth))
    for train,validation in folds:
        p,c,_ = fit_predict(features,augmented,truth,train,validation,config)
        predictions[validation],confidence[validation] = p,c
    return predictions,confidence


def summary(predictions):
    correct = np.array([[r['reference'] == r['prediction'] for r in event] for event in predictions])
    accepted = np.array([[r['confidence'] >= .55 for r in event] for event in predictions]).all(axis=1)
    return dict(events=len(correct), individual_accuracy=float(correct.mean()),all_ten_accuracy=float(correct.all(axis=1).mean()),
                vote_only_acceptance_rate=float(accepted.mean()),
                vote_only_accepted_all_ten_accuracy=float(correct[accepted].all(axis=1).mean()) if accepted.any() else None,
                warning='Vote-only .55 diagnostic, not actual app acceptance/retake rate; geometry, distance and clinical gates not reproduced here.')


def review_html(rows):
    parts = ['<!doctype html><meta charset="utf-8"><title>URITECT error review</title><style>body{font:16px system-ui;margin:24px;background:#f4fafb;color:#123d4a}table{border-collapse:collapse;width:100%}td,th{padding:10px;border:1px solid #ccd}img{max-height:180px;max-width:220px}.pad{width:96px;height:96px;image-rendering:pixelated}input{padding:10px;width:50%}tr.hide{display:none}</style>',
             '<h1>Pad error review</h1><p>Retrospective development errors. Labels are unchanged and unadjudicated. Start with Specific Gravity, Leukocytes and pH. Click context for the actual sampling boxes. Review causes in ERROR_REVIEW.csv; do not assume a color error proves an incorrect reference.</p>',
             '<p>The crop shows the baseline inner ROI; selected_crop_fraction records the candidate’s centered crop inside that ROI. No augmented image is used for evaluation.</p><input id="q" placeholder="Filter analyte, event, category or stage"><table><thead><tr><th>Stage / analyte / event</th><th>Reference → prediction</th><th>Confidence / candidate fraction</th><th>Pad crop</th><th>Context</th></tr></thead><tbody>']
    for r in rows:
        esc = lambda value: html.escape(str(value), quote=True)
        parts.append(f'<tr><td>{esc(r["stage"])}<br>{esc(r["analyte"])}<br>{esc(r["event_id"])}</td><td>{esc(r["reference"])} → {esc(r["prediction"])}<br>{esc(r["threshold_crossings"])}</td><td>{r["confidence"]:.3f}<br>{r["selected_crop_fraction"]}</td><td><a href="{r["pad_crop"]}"><img class="pad" loading="lazy" src="{r["pad_crop"]}"></a></td><td><a href="{r["context"]}"><img loading="lazy" src="{r["context"]}"></a></td></tr>')
    parts.append('</tbody></table><script>q.oninput=()=>document.querySelectorAll("tbody tr").forEach(r=>r.classList.toggle("hide",!r.textContent.toLowerCase().includes(q.value.toLowerCase())))</script>')
    (OUT/'ERROR_REVIEW.html').write_text(''.join(parts),encoding='utf-8')


def main():
    OUT.mkdir(parents=True,exist_ok=True); (OUT/'image_evidence').mkdir(exist_ok=True)
    # Cache is bound to input, script and extraction implementation hashes.
    sources = {p.relative_to(ROOT).as_posix():digest(p) for p in
               (AUDIT/'candidate_deduped.csv',AUDIT/'EVENT_AUDIT.json',Path(__file__),
                ROOT/'pipeline/markerless_strip.py',ROOT/'pipeline/specimen_grouping.py',
                ROOT/'pipeline/output/semiquant_optimization_results.json',
                ROOT/'uritect_app/assets/production_semiquant_model.json')}
    extraction_key = {k:v for k,v in sources.items() if k.endswith(('candidate_deduped.csv','EVENT_AUDIT.json','markerless_strip.py'))}
    extraction_key['extractor_functions'] = hashlib.sha256(''.join(inspect.getsource(fn) for fn in (crop_bounds,load_image,extract_event)).encode()).hexdigest()
    with (AUDIT/'candidate_deduped.csv').open(encoding='utf-8-sig',newline='') as f:
        rows = list(csv.DictReader(f))
    by_event = {}
    for row in rows:
        by_event.setdefault(row['event_id'],{})[row['analyte']] = row
    event_ids = sorted(by_event); originals = [by_event[e][ANALYTE_ORDER[0]] for e in event_ids]
    groups = np.array([specimen_group(row) for row in originals])
    truth = np.array([[by_event[e][a]['level'] for a in ANALYTE_ORDER] for e in event_ids])
    audited = {e['event_id']:e for e in json.loads((AUDIT/'EVENT_AUDIT.json').read_text())}
    cache = OUT/'FEATURE_CACHE.npz'; provenance = OUT/'EXTRACTION_PROVENANCE.json'
    saved_key = {k.replace('\\','/'):v for k,v in json.loads(provenance.read_text()).get('extraction_key',{}).items()} if provenance.exists() else {}
    if cache.exists() and provenance.exists() and saved_key == extraction_key:
        saved = np.load(cache); features, augmented = saved['features'], saved['augmented']
        geometry = json.loads(provenance.read_text())['geometry']
        print('Using hash-matched pixel feature cache',flush=True)
    else:
        features = np.empty((len(VARIANTS),len(event_ids),10,3)); augmented = np.empty((len(VARIANTS),len(event_ids),4,10,3)); geometry = [None]*len(event_ids)
        with ProcessPoolExecutor(max_workers=3) as pool:
            jobs = [pool.submit(extract_event,(i,row,audited[row['event_id']])) for i,row in enumerate(originals)]
            for count,job in enumerate(as_completed(jobs),1):
                i,x,aug,g = job.result(); features[:,i],augmented[:,i],geometry[i] = x,aug,g
                if count%25 == 0: print(f'Extracted geometry/features {count}/{len(jobs)}',flush=True)
        np.savez_compressed(cache,features=features,augmented=augmented)
        save_json('EXTRACTION_PROVENANCE.json',dict(sources=sources,extraction_key=extraction_key,geometry=geometry))
    development,confirmation = next(GroupShuffleSplit(n_splits=1,test_size=.2,random_state=42).split(event_ids,groups=groups))
    assert not set(groups[development]) & set(groups[confirmation])
    # Also check original byte-identical images cannot cross partitions.
    hashes = np.array([g['image_sha256'] for g in geometry])
    if set(hashes[development]) & set(hashes[confirmation]):
        raise ValueError('Duplicate image content crosses the group split')
    folds = [(development[tr],development[va]) for tr,va in GroupKFold(n_splits=3).split(development,groups=groups[development])]
    for tr,va in folds:
        assert not set(groups[tr]) & set(groups[va])
    save_json('SPLIT_MANIFEST.json',dict(identity_status='filename-inferred within batch; cross-batch identity unverified',
                evaluation_status='retrospective protected confirmation, NOT new untouched clinical test',
                seed=42,events=[dict(event_id=e,group=str(groups[i]),split='development' if i in development else 'confirmation',
                image_sha256=geometry[i]['image_sha256']) for i,e in enumerate(event_ids)],
                folds=[dict(train=[event_ids[i] for i in tr],validation=[event_ids[i] for i in va]) for tr,va in folds]))
    grouped_rows = [dict(row,specimen_group=specimen_group(row),experiment_split='development' if event_ids.index(row['event_id']) in development else 'confirmation') for row in rows]
    write_csv(OUT/'GROUPED_DATASET.csv',grouped_rows)
    data_quality = []
    for group in sorted(set(groups)):
        indices = np.flatnonzero(groups == group)
        for ai,a in enumerate(ANALYTE_ORDER):
            labels = sorted(set(truth[indices,ai]))
            if len(labels) > 1:
                data_quality.append(dict(group=group,analyte=a,reference_categories=';'.join(labels),events=';'.join(event_ids[i] for i in indices),
                                         status='review needed: differing captures/reference categories; no automatic relabeling'))
    write_csv(OUT/'WITHIN_GROUP_LABEL_REVIEW.csv',data_quality)
    if not data_quality:
        (OUT/'WITHIN_GROUP_LABEL_REVIEW.csv').write_text('group,analyte,reference_categories,events,status\n',encoding='utf-8')
    configurations = [dict(variant=v,scale=s,k=k,metric=m,weights=w,augmentation=False,balanced_votes=False)
                      for v,s,k,m,w in itertools.product(range(len(VARIANTS)),(False,True),(3,9,21),('euclidean','manhattan'),('distance','uniform'))]
    save_json('ANALYSIS_PLAN.json',dict(sources=sources,variants=VARIANTS,configurations=configurations,
                objective='0.65 supported-reference macro F1 + 0.35 macro sensitivity; when binary thresholds have both sides, 80% base + 20% mean threshold balanced accuracy',
                augmentation='training only: brightness .97/1.03 (skip clipping), +/-1px diagonal central crop jitter, within existing ROI; no intentional hue shifts; reject excessive feature changes and per-source duplicate vectors; inherited labels not independently verified',
                augmentation_color_bounds=dict(hsv_exposure=[5,.05,.06],hsv_jitter=[15,.12,.12],lab_exposure=[4,2,2],lab_jitter=[8,8,8]),
                refinement='top three development configs, compare training augmentation and sqrt inverse-frequency vote weighting; unchanged baseline also eligible',
                deployment='none; app model/assets unchanged',new_specimens_collected=False))
    optimization = json.loads((ROOT/'pipeline/output/semiquant_optimization_results.json').read_text())
    selected = {}; reviews = []; development_metrics = {}; baseline_oof = {}; selected_oof = {}
    for ai,analyte in enumerate(ANALYTE_ORDER):
        y = truth[:,ai]; x = features[:,:,ai,:]; aug = augmented[:,:,:,ai,:]
        leaderboard = []
        for ci,config in enumerate(configurations):
            p,c = cross_validate(x,aug,y,folds,config)
            value = measure(y[development],p[development],groups[development],analyte)
            leaderboard.append(dict(config=config,score=objective(value),metrics=value))
        leaderboard.sort(key=lambda r:r['score'],reverse=True)
        for entry in leaderboard[:3].copy():
            for augment,balance in ((True,False),(False,True),(True,True)):
                config = dict(entry['config'],augmentation=augment,balanced_votes=balance)
                p,c = cross_validate(x,aug,y,folds,config)
                value = measure(y[development],p[development],groups[development],analyte)
                leaderboard.append(dict(config=config,score=objective(value),metrics=value))
        leaderboard.sort(key=lambda r:r['score'],reverse=True)
        # Refit the installed configuration on these same development folds.
        params = optimization[analyte]; baseline = np.empty(len(y),dtype=object); bc = np.zeros(len(y))
        raw = features[0,:,ai,:]
        for tr,va in folds:
            model = _make_model(min(params['best_k'],len(tr)),params['best_metric'],params.get('feature_transform','raw'))
            model.fit(raw[tr],y[tr]); probs = model.predict_proba(raw[va]); baseline[va] = model.classes_[probs.argmax(axis=1)]; bc[va] = probs.max(axis=1)
        baseline_oof[analyte] = (baseline,bc)
        baseline_value = measure(y[development],baseline[development],groups[development],analyte)
        leaderboard.append(dict(config=dict(variant=0,legacy_params=params,augmentation=False,balanced_votes=False),score=objective(baseline_value),metrics=baseline_value))
        leaderboard.sort(key=lambda r:r['score'],reverse=True)
        best = leaderboard[0]['config']; selected[analyte] = best
        p,c = cross_validate(x,aug,y,folds,best); selected_oof[analyte] = (p,c)
        development_metrics[analyte] = dict(baseline=measure(y[development],baseline[development],groups[development],analyte),
                    selected=measure(y[development],p[development],groups[development],analyte),ranked_candidates=leaderboard)
        print(f'{analyte}: development baseline {development_metrics[analyte]["baseline"]["accuracy"]:.3f}, selected {development_metrics[analyte]["selected"]["accuracy"]:.3f}',flush=True)
    # Lock BEFORE evaluating confirmation. Re-running is reproduction, never fresh test.
    save_json('SELECTED_CONFIGURATION.json',selected)
    configuration_hash = digest(OUT/'SELECTED_CONFIGURATION.json')
    save_json('DEVELOPMENT_RESULTS.json',development_metrics)
    confirmation_metrics = {}; predictions = {}; (OUT/'candidate_models').mkdir(exist_ok=True)
    for ai,analyte in enumerate(ANALYTE_ORDER):
        y = truth[:,ai]; best = selected[analyte]
        p,c,model = fit_predict(features[:,:,ai,:],augmented[:,:,:,ai,:],y,development,confirmation,best)
        with (OUT/'candidate_models'/f'{analyte.replace(" ","_")}.pkl').open('wb') as f: pickle.dump(model,f)
        # Persist preprocessing + post-vote weighting metadata; not a drop-in Dart model.
        params = optimization[analyte]; raw = features[0,:,ai,:]
        bm = _make_model(min(params['best_k'],len(development)),params['best_metric'],params.get('feature_transform','raw'))
        bm.fit(raw[development],y[development]); probs = bm.predict_proba(raw[confirmation]); bp = bm.classes_[probs.argmax(axis=1)]; bc = probs.max(axis=1)
        confirmation_metrics[analyte] = dict(baseline=measure(y[confirmation],bp,groups[confirmation],analyte,True),
                selected=measure(y[confirmation],p,groups[confirmation],analyte,True))
        for stage,indices,pp,cc in [('development_baseline',development,*baseline_oof[analyte]),('development_selected',development,*selected_oof[analyte]),
                                  ('confirmation_baseline',confirmation,bp,bc),('confirmation_selected',confirmation,p,c)]:
            for j,i in enumerate(indices):
                pos = i if stage.startswith('development') else j
                predicted = str(pp[pos]); crossings = [name for name,levels in RULES.get(analyte,{}).items() if (y[i] in levels)!=(predicted in levels)]
                record = dict(stage=stage,event_id=event_ids[i],group=str(groups[i]),analyte=analyte,reference=str(y[i]),prediction=predicted,confidence=float(cc[pos]),
                              threshold_crossings=';'.join(crossings),selected_crop_fraction=VARIANTS[best['variant']][1] if stage.endswith('selected') else 1.,
                              pad_crop=f'image_evidence/{i:04d}_{ai:02d}.jpg',context=geometry[i]['context'])
                predictions.setdefault(stage,{}).setdefault(event_ids[i],[]).append(record)
                if predicted != y[i]:
                    reviews.append(dict(record,localization_issue='unreviewed',reference_issue='unreviewed',lighting_issue='unreviewed',timing_issue='unknown',reviewer='',adjudicated_label='',review_notes=''))
    summaries = {stage:summary(list(events.values())) for stage,events in predictions.items()}
    save_json('CONFIRMATION_RESULTS.json',dict(selected_configuration_sha256=configuration_hash,per_analyte=confirmation_metrics,summary=summaries))
    save_json('PREDICTIONS.json',predictions)
    if digest(ROOT/'uritect_app/assets/production_semiquant_model.json') != sources['uritect_app/assets/production_semiquant_model.json']:
        raise ValueError('Live app model changed during the experiment')
    import sklearn, sys
    save_json('RUN_EVIDENCE.json',dict(runtime=dict(python=sys.version,sklearn=sklearn.__version__,numpy=np.__version__,opencv=cv2.__version__),
                sources=sources,app_model_unchanged=True,new_specimens_collected=False,gold_labels_changed=False,
                group_overlap=0,image_hash_overlap=0,configuration_sha256=configuration_hash,
                within_group_category_disagreements=len(data_quality)))
    priority = {'Specific Gravity':0,'Leukocytes':1,'pH':2}
    reviews.sort(key=lambda r:(priority.get(r['analyte'],3),r['stage'],r['event_id']))
    write_csv(OUT/'ERROR_REVIEW.csv',reviews); review_html(reviews)
    lines = ['# Direction-verified kNN improvement experiment','',
        'Retrospective research development only. The installed app, reference labels and frozen APK are unchanged. Filename-derived within-batch grouping is corrected; identity across batches is unverified. Existing data have previously been inspected, so confirmation is not a new untouched test.',
        '',f'{len(event_ids)} direction-verified events; {len(development)} development / {len(confirmation)} confirmation events. {len(set(groups))} inferred within-batch identities. 219 earlier events excluded by the existing direction/geometry audit; no new specimens collected.',
        '', 'Selection used three group-separated development folds, macro F1, class sensitivity and supported analytical/rule thresholds. Scaling and augmentation fit training partitions only. Confirmation was evaluated after configuration lock. A pre-guard engineering pass is archived separately; the reserved subset has been evaluated in repeated engineering passes and is not an independent final test. No clinical acceptance criteria are invented.',
        '', '| Analyte | Baseline confirmation accuracy | Candidate confirmation accuracy | Candidate macro F1 | Candidate macro sensitivity | Candidate macro specificity | Candidate kappa |', '|---|---:|---:|---:|---:|---:|---:|']
    for a,v in confirmation_metrics.items():
        b,s = v['baseline'],v['selected']; fmt = lambda x:'undefined' if x is None else f'{x:.4f}'
        lines.append(f'|{a}|{b["accuracy"]:.2%}|{s["accuracy"]:.2%}|{fmt(s["macro_f1_supported_reference_classes"])}|{fmt(s["macro_sensitivity"])}|{fmt(s["macro_specificity"])}|{fmt(s["cohens_kappa"])}|')
    lines += ['', 'Macro sensitivity/specificity use defined one-vs-rest denominators; absent reference classes are listed in JSON. These are category metrics, not disease detection. Nitrite-positive sensitivity is undefined when no positive reference exists; kappa is undefined for a single class.', '', '## Whole-scan and coverage diagnostics','']
    for stage,s in summaries.items(): lines.append(f'- {stage}: individual {s["individual_accuracy"]:.2%}; all-ten {s["all_ten_accuracy"]:.2%}; vote-only acceptance {s["vote_only_acceptance_rate"]:.2%}.')
    lines += ['', 'Vote-only acceptance is not the measured app retake rate: detection, absolute distance, timing, eligibility and safety gates are omitted. Confidence is kNN vote agreement, not a calibrated probability. Balanced votes change its meaning and need runtime validation before deployment.', '',
              '## Review and deployment status','',f'{len(reviews)} failed prediction rows across baseline/candidate development/confirmation comparisons. Open ERROR_REVIEW.html locally for real pad crops and contexts; ERROR_REVIEW.csv has blank reviewer/adjudication fields. No reference corrections were invented.', '',
              'Candidate models are development-trained comparison artifacts, not production exports. SELECTED_CONFIGURATION.json defines feature conversion, scaling, augmentation and optional sqrt inverse-frequency post-vote weighting; the pickles alone do not implement post-vote weighting. Any app replacement needs matching Dart feature extraction, support-envelope regeneration, parity tests, release build and device tests. Do not promote based on overall accuracy alone.', '',
              'Feature comparison includes AWB versus raw color, normalized versus absolute circular HSV versus Lab, full/75%/50% inner crop, scaling, k=3/9/21, Manhattan/Euclidean and uniform/distance votes. The top three development settings also compare augmentation and class-prior weighting. Exact augmented repeats and excessive feature changes are skipped. Augmentation inherits labels and remains an assumption; it adds no independent biological information.', '',
              'Reproduce: `.venv/Scripts/python pipeline/improve_direction_verified_knn.py`. Input/script hashes, real-image SHA256s, fold assignments, baseline extraction parity, predictions, ranked candidates, configuration lock and threshold-support/cluster-interval evidence are saved beside this report. Reproducing an already inspected confirmation set does not make it untouched.']
    (OUT/'REPORT.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps(summaries,indent=2),flush=True)


if __name__ == '__main__':
    main()
