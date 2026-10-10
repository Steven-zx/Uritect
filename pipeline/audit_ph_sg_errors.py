"""Focused label-preserving crop audit and nested grouped development benchmark.

The old 112-event confirmation subset is NOT used to select or assess new
settings. No model assets, reference labels, release APKs or clinical rules change.
"""
import argparse
import csv
import hashlib
import html
import json
from collections import Counter,defaultdict
from concurrent.futures import ProcessPoolExecutor,as_completed
from pathlib import Path

import cv2
import numpy as np
from sklearn.model_selection import GroupKFold
from sklearn.neighbors import KNeighborsClassifier
from sklearn.preprocessing import StandardScaler
from threadpoolctl import threadpool_limits

from focused_pad_geometry import audit_pad
from improve_direction_verified_knn import load_image,crop_bounds,measure,_make_model
from runtime_pad_features import mean_pad_hsv,normalize_pad_hsv
from semiquant_schema import ANALYTE_ORDER

_LIMIT = threadpool_limits(1)
ROOT = Path(__file__).resolve().parents[1]
PREVIOUS = ROOT/'pipeline/output/knn_improvement_2026-10-11'
OUT = ROOT/'pipeline/output/ph_sg_error_audit_2026-10-11'
TARGETS = ('pH','Specific Gravity')
RECIPES = ('runtime_normalized','runtime_raw','runtime_hs','dense_normalized','dense_raw',
           'half_raw','refined_raw','refined_normalized','backing_raw','backing_hs','raw_lab','refined_lab')


def dump(name,value):
    (OUT/name).write_text(json.dumps(value,indent=2,allow_nan=False)+'\n',encoding='utf-8')


def csv_file(name,rows,fields=None):
    with (OUT/name).open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=fields or list(rows[0]));writer.writeheader();writer.writerows(rows)


def circular(values,hs=False):
    h,s,v = values
    return [np.cos(np.radians(h)),np.sin(np.radians(h)),s] if hs else [np.cos(np.radians(h)),np.sin(np.radians(h)),s,v]


def backing_gains(image,rois):
    """Neutral backing between pads; no reference category enters this rule."""
    white=[]
    for a,b in zip(ANALYTE_ORDER,ANALYTE_ORDER[1:]):
        x,y,w,h=rois[a];_,ny,_,nh=rois[b]
        center=int(round((y+h/2+ny+nh/2)/2));gap=ny+nh/2-y-h/2
        half=max(1,int(round(gap*.07)));cx=int(round(x+w/2));hw=max(2,int(round(w*.35)))
        patch=image[max(0,center-half):center+half+1,max(0,cx-hw):cx+hw+1]
        hsv=cv2.cvtColor(patch,cv2.COLOR_BGR2HSV).astype(float)/255.
        neutral=(hsv[...,1]<.2)&(hsv[...,2]>.3)&(hsv[...,2]<.98)
        if neutral.sum()>=8:white.extend(patch[neutral].tolist())
    if len(white)<20:return np.ones(3),False
    mean=np.median(np.array(white,dtype=float),axis=0);target=mean.mean()
    return np.clip(target/np.maximum(mean,1),.75,1.33),True


def lab(image,roi):
    x,y,w,h=map(int,roi)
    patch=image[y:y+h,x:x+w].astype(np.float32)/255.
    return cv2.cvtColor(patch,cv2.COLOR_BGR2LAB).reshape(-1,3).mean(axis=0).tolist()


def extract(item):
    index,row,geometry=item
    image,image_hash=load_image(row)
    assert image_hash==geometry['image_sha256'],'Original image changed'
    orientation=geometry['orientation']
    if orientation!='exif':image=cv2.rotate(image,{'rot90_cw':cv2.ROTATE_90_CLOCKWISE,'rot180':cv2.ROTATE_180,'rot90_ccw':cv2.ROTATE_90_COUNTERCLOCKWISE}[orientation])
    rois=geometry['rois'];gains=geometry['awb_gains']
    centers=[rois[a][1]+rois[a][3]/2 for a in ANALYTE_ORDER];gap=float(np.median(np.diff(centers)))
    raw=np.array([mean_pad_hsv(image,rois[a],gains) for a in ANALYTE_ORDER])
    dense=np.array([mean_pad_hsv(image,rois[a],gains,dense=True) for a in ANALYTE_ORDER])
    normalized=normalize_pad_hsv(raw);dense_norm=normalize_pad_hsv(dense)
    audits={a:audit_pad(image,rois[a],gap) for a in TARGETS}
    refined_rois={a:audits[a]['refined_roi'] if a in TARGETS else rois[a] for a in ANALYTE_ORDER}
    refined=np.array([mean_pad_hsv(image,refined_rois[a],gains) for a in ANALYTE_ORDER]);refined_norm=normalize_pad_hsv(refined)
    backing,backing_available=backing_gains(image,rois)
    values={name:[] for name in RECIPES};records=[]
    folder=OUT/'image_evidence'
    for a in TARGETS:
        ai=ANALYTE_ORDER.index(a);roi=rois[a];refined_roi=refined_rois[a]
        half=mean_pad_hsv(image,crop_bounds(roi,.5),gains)
        white=mean_pad_hsv(image,roi,backing)
        features=dict(runtime_normalized=circular(normalized[ai]),runtime_raw=circular(raw[ai]),runtime_hs=circular(raw[ai],True),
                      dense_normalized=circular(dense_norm[ai]),dense_raw=circular(dense[ai]),half_raw=circular(half),
                      refined_raw=circular(refined[ai]),refined_normalized=circular(refined_norm[ai]),backing_raw=circular(white),backing_hs=circular(white,True),
                      raw_lab=lab(image,roi),refined_lab=lab(image,refined_roi))
        for name in RECIPES:values[name].append(features[name])
        x,y,w,h=map(int,roi);half_w=int(round(w*1.6));half_h=int(round(gap*.48));cx=x+w//2;cy=y+h//2
        ox,oy=max(0,cx-half_w),max(0,cy-half_h)
        context=image[oy:min(image.shape[0],cy+half_h+1),ox:min(image.shape[1],cx+half_w+1)].copy()
        cv2.rectangle(context,(x-ox,y-oy),(x+w-ox,y+h-oy),(230,180,0),1)
        rx,ry,rw,rh=map(int,refined_roi);cv2.rectangle(context,(rx-ox,ry-oy),(rx+rw-ox,ry+rh-oy),(180,0,210),1)
        key=f'{index:04d}_{ai:02d}'
        cv2.imwrite(str(folder/f'{key}_context.png'),context)
        cv2.imwrite(str(folder/f'{key}_crop.png'),image[y:y+h,x:x+w])
        cv2.imwrite(str(folder/f'{key}_refined.png'),image[ry:ry+rh,rx:rx+rw])
        records.append(dict(event_id=row['event_id'],analyte=a,**audits[a],backing_reference_available=backing_available,
                            runtime_raw_hsv=raw[ai].tolist(),runtime_normalized_hsv=normalized[ai].tolist(),
                            raw_to_dense_hue_difference=float(abs((raw[ai,0]-dense[ai,0]+180)%360-180)),
                            context=f'image_evidence/{key}_context.png',crop=f'image_evidence/{key}_crop.png',refined_crop=f'image_evidence/{key}_refined.png'))
    return index,values,records


def fit(x,y,train,test,config):
    scale=StandardScaler().fit(x[train]) if config['scale'] else None
    tx=scale.transform(x[train]) if scale else x[train];vx=scale.transform(x[test]) if scale else x[test]
    model=KNeighborsClassifier(n_neighbors=min(config['k'],len(train)),metric='euclidean',weights='distance',algorithm='kd_tree',n_jobs=1).fit(tx,y[train])
    probs=model.predict_proba(vx)
    if config['balance']:
        counts=np.array([(y[train]==label).sum() for label in model.classes_]);probs/=counts**config['balance'];probs/=probs.sum(axis=1,keepdims=True)
    return model.classes_[probs.argmax(axis=1)],probs.max(axis=1)


def score(value):
    return .65*value['macro_f1_supported_reference_classes']+.35*value['macro_sensitivity']


def benchmark(features,labels,groups,manifest,baseline):
    events=[e['event_id'] for e in manifest['events']];lookup={e:i for i,e in enumerate(events)}
    development=np.array([i for i,e in enumerate(manifest['events']) if e['split']=='development'])
    folds=[(np.array([lookup[e] for e in f['train']]),np.array([lookup[e] for e in f['validation']])) for f in manifest['folds']]
    configurations=[dict(recipe=recipe,scale=scale,k=k,balance=balance) for recipe in RECIPES for scale in (False,True) for k in (3,9,21) for balance in (0.,.25,.5)]
    dump('ANALYSIS_PLAN.json',dict(purpose='Nested group CV within the 453 prior development events only; no confirmation evaluation',
         configurations=configurations,selection='0.65 supported-reference macro F1 + 0.35 macro sensitivity',
         engineering_promotion_screen='OOF macro F1 gain >= .02, no accuracy or macro-sensitivity loss, score improvement in at least 2 of 3 outer folds; not clinical acceptance criteria',
         label_changes=False,new_specimens=False,app_asset_replacement=False))
    optimization=json.loads((ROOT/'pipeline/output/semiquant_optimization_results.json').read_text())
    results={};predictions=[]
    for ai,a in enumerate(TARGETS):
        y=labels[:,ai];bp=np.empty(len(y),object);bc=np.zeros(len(y));chosen=np.empty(len(y),object);confidence=np.zeros(len(y));fold_reports=[]
        for fi,(train,validation) in enumerate(folds):
            assert not set(groups[train])&set(groups[validation])
            inner=[(train[tr],train[va]) for tr,va in GroupKFold(3).split(train,groups=groups[train])]
            ranked=[]
            for config in configurations:
                x=features[config['recipe']][:,ai];p=np.empty(len(y),object)
                for tr,va in inner:p[va],_=fit(x,y,tr,va,config)
                value=measure(y[train],p[train],groups[train],a)
                ranked.append(dict(config=config,score=score(value),metrics=value))
            # Existing baseline is also eligible inside INNER validation.
            params=optimization[a];p=np.empty(len(y),object)
            for tr,va in inner:
                model=_make_model(min(params['best_k'],len(tr)),params['best_metric'],params.get('feature_transform','raw')).fit(baseline[tr,ai],y[tr])
                p[va]=model.predict(baseline[va,ai])
            base_inner=measure(y[train],p[train],groups[train],a)
            ranked.append(dict(config={'recipe':'unchanged_baseline'},score=score(base_inner),metrics=base_inner))
            ranked.sort(key=lambda r:r['score'],reverse=True);best=ranked[0]['config']
            model=_make_model(min(params['best_k'],len(train)),params['best_metric'],params.get('feature_transform','raw')).fit(baseline[train,ai],y[train])
            probs=model.predict_proba(baseline[validation,ai]);bp[validation]=model.classes_[probs.argmax(axis=1)];bc[validation]=probs.max(axis=1)
            if best['recipe']=='unchanged_baseline':chosen[validation],confidence[validation]=bp[validation],bc[validation]
            else:chosen[validation],confidence[validation]=fit(features[best['recipe']][:,ai],y,train,validation,best)
            b=measure(y[validation],bp[validation],groups[validation],a);c=measure(y[validation],chosen[validation],groups[validation],a)
            fold_reports.append(dict(fold=fi,selected_on_inner_folds=best,baseline=b,candidate=c,inner_ranked_candidates=ranked))
            print(f'{a} outer fold {fi+1}: baseline {b["accuracy"]:.3f}, selected {c["accuracy"]:.3f}; {best}',flush=True)
        b=measure(y[development],bp[development],groups[development],a,True);c=measure(y[development],chosen[development],groups[development],a,True)
        wins=sum(score(f['candidate'])>score(f['baseline']) for f in fold_reports)
        eligible=(c['macro_f1_supported_reference_classes']>=b['macro_f1_supported_reference_classes']+.02 and c['accuracy']>=b['accuracy'] and c['macro_sensitivity']>=b['macro_sensitivity'] and wins>=2)
        # Same old settings retrained on app-style features: diagnostic parity effect.
        rx=np.array([r[ai] for r in baseline]);runtime=features['runtime_normalized'][:,ai]
        raw_hsv=np.column_stack([np.degrees(np.arctan2(runtime[:,1],runtime[:,0]))%360,runtime[:,2:]])
        rp=np.empty(len(y),object)
        for tr,va in folds:
            model=_make_model(min(params['best_k'],len(tr)),params['best_metric'],params.get('feature_transform','raw')).fit(raw_hsv[tr],y[tr]);rp[va]=model.predict(raw_hsv[va])
        parity_refit=measure(y[development],rp[development],groups[development],a)
        results[a]=dict(baseline=b,nested_selected=c,folds=fold_reports,outer_score_wins=wins,engineering_screen_passed=bool(eligible),
                        runtime_compatible_refit_same_settings=parity_refit,
                        deployment='not changed; selected features and geometry need app parity and support-policy work before model export')
        for i in development:
            predictions.append(dict(event_id=events[i],group=str(groups[i]),analyte=a,reference=str(y[i]),baseline_prediction=str(bp[i]),
                                    nested_prediction=str(chosen[i]),baseline_confidence=float(bc[i]),nested_confidence=float(confidence[i]),
                                    runtime_refit_prediction=str(rp[i])))
    dump('NESTED_DEVELOPMENT_RESULTS.json',results);csv_file('NESTED_PREDICTIONS.csv',predictions)
    return results,predictions


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--audit-only',action='store_true');args=parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'image_evidence').mkdir(exist_ok=True)
    sources={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in
             (Path(__file__),ROOT/'pipeline/runtime_pad_features.py',ROOT/'pipeline/focused_pad_geometry.py',
              PREVIOUS/'EXTRACTION_PROVENANCE.json',PREVIOUS/'SPLIT_MANIFEST.json',
              ROOT/'uritect_app/assets/production_semiquant_model.json')}
    manifest=json.loads((PREVIOUS/'SPLIT_MANIFEST.json').read_text());events=[e['event_id'] for e in manifest['events']]
    geometry=json.loads((PREVIOUS/'EXTRACTION_PROVENANCE.json').read_text())['geometry'];geo={g['event_id']:g for g in geometry}
    with (PREVIOUS/'GROUPED_DATASET.csv').open(encoding='utf-8-sig',newline='') as f:rows=list(csv.DictReader(f))
    original={};rowlabels={}
    for r in rows:original.setdefault(r['event_id'],r);rowlabels[(r['event_id'],r['analyte'])]=r['level']
    labels=np.array([[rowlabels[(e,a)] for a in TARGETS] for e in events]);groups=np.array([e['group'] for e in manifest['events']])
    previous=np.load(PREVIOUS/'FEATURE_CACHE.npz')['features'][0]
    baseline=previous[:,[ANALYTE_ORDER.index(a) for a in TARGETS],:]
    # The previous cache is ordered by sorted event IDs, as is its manifest.
    assert events==sorted(events)
    cache=OUT/'TARGET_FEATURES.npz';audit_file=OUT/'CROP_AUDIT.json';key_file=OUT/'EXTRACTION_KEY.json'
    key=dict(sources=sources,recipes=RECIPES)
    if cache.exists() and key_file.exists() and json.loads(key_file.read_text())==json.loads(json.dumps(key)):
        saved=np.load(cache);features={name:saved[name] for name in RECIPES};records=json.loads(audit_file.read_text());print('Using exact-hash focused feature cache',flush=True)
    else:
        features={name:np.empty((len(events),2,3 if name.endswith(('hs','lab')) else 4)) for name in RECIPES};records=[]
        with ProcessPoolExecutor(max_workers=3) as pool:
            jobs=[pool.submit(extract,(i,original[e],geo[e])) for i,e in enumerate(events)]
            for count,job in enumerate(as_completed(jobs),1):
                i,values,audits=job.result()
                for name in RECIPES:features[name][i]=values[name]
                records.extend(audits)
                if count%50==0:print(f'Audited raw pH/SG crops {count}/{len(events)}',flush=True)
        np.savez_compressed(cache,**features);dump('CROP_AUDIT.json',sorted(records,key=lambda r:(r['event_id'],r['analyte'])));dump('EXTRACTION_KEY.json',key)
    development={e['event_id'] for e in manifest['events'] if e['split']=='development'}
    prior=json.loads((PREVIOUS/'PREDICTIONS.json').read_text())['development_baseline']
    audit_summary={};review=[];numeric=[]
    for a in TARGETS:
        rs=[r for r in records if r['analyte']==a and r['event_id'] in development]
        for r in rs:
            old=next(p for p in prior[r['event_id']] if p['analyte']==a);i=events.index(r['event_id']);ai=TARGETS.index(a)
            raw=np.array(r['runtime_normalized_hsv']);old_vector=baseline[i,ai]
            hue_delta=float(abs((raw[0]-old_vector[0]+180)%360-180))
            audit=dict(r,reference=rowlabels[(r['event_id'],a)],baseline_prediction=old['prediction'],baseline_confidence=old['confidence'],
                       baseline_wrong=old['reference']!=old['prediction'],python_to_runtime_hue_difference=hue_delta,
                       python_to_runtime_s_difference=float(abs(raw[1]-old_vector[1])),python_to_runtime_v_difference=float(abs(raw[2]-old_vector[2])),
                       review_status='automated flag, not clinical adjudication',reference_label_action='unchanged')
            numeric.append(audit)
        wrong=[r for r in numeric if r['analyte']==a and r['baseline_wrong']]
        correct=[r for r in numeric if r['analyte']==a and not r['baseline_wrong']]
        def describe(values):
            supported=[r for r in values if r['original_color_support'] is not None]
            return dict(n=len(values),boundary_supported=len(supported),color_support_below_95=sum(r['original_color_support']<.95 for r in supported),
                        median_neutral_fraction=float(np.median([r['neutral_fraction'] for r in values])),
                        median_feature_hue_mismatch=float(np.median([r['python_to_runtime_hue_difference'] for r in values])),
                        hue_mismatch_above_5_degrees=sum(r['python_to_runtime_hue_difference']>5 for r in values))
        audit_summary[a]=dict(reference_counts=dict(Counter(r['reference'] for r in numeric if r['analyte']==a)),
                             reference_support_groups={label:len({groups[events.index(r['event_id'])] for r in numeric if r['analyte']==a and r['reference']==label}) for label in set(labels[:,TARGETS.index(a)])},
                             errors=describe(wrong),correct=describe(correct))
    numeric.sort(key=lambda r:(not r['baseline_wrong'],r['original_color_support'] if r['original_color_support'] is not None else 1,r['analyte']))
    # Review only development examples, with correct controls retained.
    review=numeric
    flat=[{k:v for k,v in r.items() if k not in ('runtime_raw_hsv','runtime_normalized_hsv')} for r in review]
    csv_file('FOCUSED_REVIEW.csv',flat)
    parts=['<!doctype html><meta charset="utf-8"><title>pH / SG crop audit</title><style>body{font:16px system-ui;color:#123d4a;margin:24px;background:#f4fafb}td,th{padding:10px;border:1px solid #ccd}table{border-collapse:collapse}.crop{width:96px;height:96px;image-rendering:pixelated}.context{max-width:230px;max-height:200px}input{padding:12px;width:55%}</style><h1>pH and specific gravity crop audit</h1><p>Development photos only. Cyan: original ROI; magenta: experimental local color-boundary ROI. Low color support is a review flag, not proof of white backing or incorrect labels. All reference labels unchanged. Click a context for full resolution.</p><input id="q" placeholder="Filter event, analyte, category or baseline prediction"><table><thead><tr><th>Case</th><th>Audit</th><th>Original</th><th>Refined</th><th>Context</th></tr></thead><tbody>']
    for r in review:
        esc=lambda v:html.escape(str(v),quote=True)
        parts.append(f'<tr><td>{esc(r["event_id"])}<br>{esc(r["analyte"])}<br>{esc(r["reference"])} → {esc(r["baseline_prediction"])}<br>wrong: {r["baseline_wrong"]}</td><td>{esc(r["boundary_status"])}<br>Color support: {esc(r["original_color_support"])}<br>Neutral pixels: {r["neutral_fraction"]:.1%}<br>Hue feature mismatch: {r["python_to_runtime_hue_difference"]:.2f}°</td><td><img class="crop" loading="lazy" src="{r["crop"]}"></td><td><img class="crop" loading="lazy" src="{r["refined_crop"]}"></td><td><a href="{r["context"]}"><img class="context" loading="lazy" src="{r["context"]}"></a></td></tr>')
    parts.append('</tbody></table><script>q.oninput=()=>document.querySelectorAll("tbody tr").forEach(r=>r.hidden=!r.textContent.toLowerCase().includes(q.value.toLowerCase()))</script>')
    (OUT/'FOCUSED_REVIEW.html').write_text(''.join(parts),encoding='utf-8');dump('AUDIT_SUMMARY.json',audit_summary)
    result=None
    if not args.audit_only:result,pred=benchmark(features,labels,groups,manifest,baseline)
    dump('RUN_EVIDENCE.json',dict(sources=sources,reference_labels_changed=False,confirmation_used_for_tuning=False,
              app_model_unchanged=hashlib.sha256((ROOT/'uritect_app/assets/production_semiquant_model.json').read_bytes()).hexdigest()==sources['uritect_app/assets/production_semiquant_model.json'],
              development_events=len(development),audited_development_pads=len(review),audit_summary=audit_summary))
    lines=['# Focused pH / specific-gravity audit','',
           'Reference labels and app model are unchanged. Only the prior 453-event development subset enters error ranking and nested model selection. The already-inspected confirmation subset is not evaluated again. Filename-inferred identities remain unverified across batches.', '',
           '[Visual review](FOCUSED_REVIEW.html) · [Editable review CSV](FOCUSED_REVIEW.csv) · [Audit summary](AUDIT_SUMMARY.json)','',
           'The training and app color extractors differ: OpenCV quantized arithmetic hue/all-pixel means versus float corrected RGB/circular hue/strided sampling. Quantities below use identical supplied ROIs and gains; they do not establish decoder, resize, AWB-estimator or full detector parity.','']
    for a,s in audit_summary.items():
        lines += [f'## {a}','',f'Reference counts: {s["reference_counts"]}. Supporting inferred groups: {s["reference_support_groups"]}.',
                  '',f'Failed predictions: {s["errors"]}. Correct controls: {s["correct"]}.','']
    if result:
        lines += ['## Nested development comparison','', '| Analyte | Baseline accuracy | Candidate accuracy | Baseline macro F1 | Candidate macro F1 | Baseline macro sensitivity | Candidate macro sensitivity | Engineering screen |', '|---|---:|---:|---:|---:|---:|---:|---|']
        for a,r in result.items():
            b,c=r['baseline'],r['nested_selected']
            lines.append(f'|{a}|{b["accuracy"]:.2%}|{c["accuracy"]:.2%}|{b["macro_f1_supported_reference_classes"]:.4f}|{c["macro_f1_supported_reference_classes"]:.4f}|{b["macro_sensitivity"]:.4f}|{c["macro_sensitivity"]:.4f}|{r["engineering_screen_passed"]}|')
        lines += ['', 'The candidate column is the nested selection procedure: each outer fold selects its own configuration using inner training/validation folds only. It is not a single frozen deployable model. All five metrics, class confusion counts, fold configurations and ranked inner comparisons are in NESTED_DEVELOPMENT_RESULTS.json.', '',
                  'Local color-boundary refinement is experimental and falls back to the existing ROI when evidence is weak. It never changes physical analyte order. Brightness is tested separately from hue/saturation; backing calibration uses neutral inter-pad pixels, not other reagent categories. No threshold is described as clinically safe.', '',
                  'Deployment remains unchanged until a stable single recipe passes engineering comparison and Python/Dart parity with regenerated model-bound distance support. Reference-label or reaction-time errors require actual reference evidence; none are fabricated by this audit.']
    (OUT/'REPORT.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps(audit_summary,indent=2),flush=True)


if __name__=='__main__':main()
