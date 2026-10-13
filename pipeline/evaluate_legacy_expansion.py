"""Paired development-only comparison of verified legacy data additions.

The inspected 112-event confirmation subset and all related known groups remain
outside selection. Fixed existing per-analyte kNN settings; no threshold easing.
Only separately audited photographs with supplied complete references are added.
"""
import argparse
import copy
import csv
import hashlib
import json
import re
from pathlib import Path

import numpy as np
from scipy.spatial.distance import cdist
from sklearn.model_selection import GroupKFold
from threadpoolctl import threadpool_limits

from audit_legacy_dataset import DEFAULT_OUT, ROOT, dump, file_digest, safe_id
from audit_abnormal_detection import RULES, binary_counts
from build_training_support_policy import build_policy
from export_production_model_json import _knn_from_model, _scaler_from_model, _labels_from_knn, _round_matrix
from freeze_production_semiquant import _make_model
from improve_direction_verified_knn import measure
from semiquant_schema import ANALYTE_ORDER
from specimen_grouping import specimen_group
from vision_pipeline import feature_columns_for_analyte

LIMIT = threadpool_limits(limits=1)
PREVIOUS = ROOT / 'pipeline/output/knn_improvement_2026-10-11'
MODEL = ROOT / 'uritect_app/assets/production_semiquant_model.json'


def group_name(row):
    group = specimen_group(row)
    batch, participant = group.split('|',1)
    if batch.startswith('LAUAAN'): batch = 'uritect_2026-7-30_Laua-an'
    if re.fullmatch(r'P\d+',participant): participant = participant[1:]
    return f'{batch}|{safe_id(participant)}'


def baseline_data():
    rows=list(csv.DictReader((PREVIOUS/'GROUPED_DATASET.csv').open(encoding='utf-8-sig',newline='')))
    events={}
    for row in rows:
        e=row['event_id']
        if e not in events:
            events[e]=dict(event_id=e,group=group_name(row),family=group_name(row).split('|')[0],
                split=row['experiment_split'],features=np.array([[float(row[c]) for c in feature_columns_for_analyte(a,'normalized_hsv')] for a in ANALYTE_ORDER]),labels={})
        events[e]['labels'][row['analyte']]=row['level']
    evidence=json.loads((PREVIOUS/'EXTRACTION_PROVENANCE.json').read_text())['geometry']
    hashes={r['event_id']:r['image_sha256'] for r in evidence}
    for e,value in events.items():value['image_sha256']=hashes[e]
    return list(events.values())


def tokens(records):
    result=set()
    for r in records:
        for value in [r['group'].split('|')[-1],r.get('subject_alias','')]:
            if value and str(value).isdigit():result.add(safe_id(value))
    return result


def trained_predict(train,validation,spec,ai):
    x=np.array([r['features'][ai] for r in train]); y=np.array([r['labels'][ANALYTE_ORDER[ai]] for r in train])
    vx=np.array([r['features'][ai] for r in validation])
    model=_make_model(min(spec['k'],len(train)),spec['metric'],spec['feature_transform'])
    model.fit(x,y)
    prediction=model.predict(vx); confidence=model.predict_proba(vx).max(axis=1)
    estimator=_knn_from_model(model)
    tx=estimator._fit_X
    transformed=model[:-1].transform(vx) if hasattr(model,'steps') else vx
    unique=np.unique(tx,axis=0)
    distances=cdist(unique,unique,metric={'manhattan':'cityblock'}.get(spec['metric'],spec['metric']))
    np.fill_diagonal(distances,np.inf)
    radius=float(distances.min(axis=1).max())
    nearest=cdist(transformed,tx,metric={'manhattan':'cityblock'}.get(spec['metric'],spec['metric'])).min(axis=1)
    return prediction,confidence,nearest<=radius+1e-10


def cluster_delta(truth,old,new,groups):
    unique=sorted(set(groups))
    counts=np.array([np.sum(groups==g) for g in unique])
    differences=np.array([np.sum(new[groups==g]==truth[groups==g])-np.sum(old[groups==g]==truth[groups==g]) for g in unique])
    rng=np.random.default_rng(20261013)
    draws=rng.integers(0,len(unique),size=(2000,len(unique)))
    value=differences[draws].sum(axis=1)/counts[draws].sum(axis=1)
    low,high=np.quantile(value,[.025,.975])
    return dict(point=float((new==truth).mean()-(old==truth).mean()),low=float(low),high=float(high),
        method='paired percentile bootstrap of within-batch groups, 2000 resamples; provisional identities')


def screen(old,new,delta):
    reasons=[]
    for key in ['accuracy','macro_f1_supported_reference_classes','macro_sensitivity','macro_specificity']:
        if new.get(key) is None or old.get(key) is None or new[key] < old[key]-1e-12:
            reasons.append(f'{key} decreased or undefined')
    if delta['low'] <= 0:reasons.append('Paired group accuracy improvement interval includes zero')
    if new['macro_f1_supported_reference_classes'] <= old['macro_f1_supported_reference_classes']+1e-12:
        reasons.append('No macro F1 improvement')
    for name,base in old['reference_label_thresholds'].items():
        candidate=new['reference_label_thresholds'][name]
        for key in ['sensitivity','specificity']:
            if base[key] is not None and (candidate[key] is None or candidate[key]<base[key]-1e-12):
                reasons.append(f'{name} {key} decreased')
    if len([c for c in new['class_metrics'].values() if c['positive_support']])<2:
        reasons.append('No abnormal/category diversity in the evaluation references')
    return dict(passed=not reasons,reasons=reasons)


def whole(truth,prediction,confidence,support,threshold):
    correct=np.all(truth==prediction,axis=1)
    accepted=np.all(confidence>=threshold,axis=1)&np.all(support,axis=1)
    return dict(events=len(truth),individual_accuracy=float((truth==prediction).mean()),
        all_ten_accuracy=float(correct.mean()),feature_stage_accepted=int(accepted.sum()),
        feature_stage_retake_rate=float(1-accepted.mean()),
        feature_stage_accepted_all_ten_accuracy=float(correct[accepted].mean()) if accepted.any() else None,
        scope='Fixed target development photos with known localization. This is not end-to-end APK acceptance or disease accuracy.')


def export_spec(records,spec,ai):
    x=np.array([r['features'][ai] for r in records]);y=np.array([r['labels'][ANALYTE_ORDER[ai]] for r in records])
    fitted=_make_model(min(spec['k'],len(records)),spec['metric'],spec['feature_transform']).fit(x,y)
    knn=_knn_from_model(fitted);scaler=_scaler_from_model(fitted)
    result=copy.deepcopy(spec)
    result.update(k=knn.n_neighbors,train_vectors=_round_matrix(np.asarray(knn._fit_X)),train_labels=_labels_from_knn(knn),
        scaler={'mean':[round(float(v),10) for v in scaler.mean_],'scale':[round(float(v),10) for v in scaler.scale_]} if scaler else None)
    result['source_metadata']=dict(model_version='direction_verified_experimental_legacy_v2_20261013',
        feature_space='normalized_hsv',k=result['k'],metric=result['metric'],feature_transform=result['feature_transform'],
        n_samples=len(records),n_levels=len(set(y)),source='legacy_dataset_audit_2026-10-13/CLEAN_FEATURES.csv',
        clinical_validation_established=False)
    return result


def run(out):
    out=Path(out)
    if (out/'DEVELOPMENT_COMPARISON.json').exists():
        raise RuntimeError('Evaluation already recorded; choose a new experiment rather than overwrite metrics')
    original_bytes=MODEL.read_bytes();model=json.loads(original_bytes)
    baseline=baseline_data()
    audit=json.loads((out/'FINAL_PHOTO_AUDIT.json').read_text())
    all_audited={r['image_sha256']:r for r in audit}
    for r in baseline:r['subject_alias']=all_audited.get(r['image_sha256'],{}).get('subject_alias','')
    pool=[]
    for r in audit:
        if r['status']=='accepted_training':
            r=dict(r,features=np.array([r['features'][a] for a in ANALYTE_ORDER]))
            pool.append(r)
    original_hashes={r['image_sha256'] for r in baseline}
    new=[r for r in pool if r['image_sha256'] not in original_hashes]
    audited={r['image_sha256']:r for r in pool}
    original_development=[r for r in baseline if r['split']=='development']
    # A final cleaned model cannot retain a feature row that failed this audit.
    # Both arms are assessed on the same freshly verified held-out pad features.
    development=[]
    for r in original_development:
        if r['image_sha256'] in audited:
            clean=audited[r['image_sha256']]
            if clean['labels'] != r['labels']:continue
            development.append(dict(clean,event_id=r['event_id'],split='development'))
    confirmation=[r for r in baseline if r['split']=='confirmation']
    confirmed_groups={r['group'] for r in confirmation}
    safe_pool=[r for r in pool if r['group'] not in confirmed_groups and not tokens([r])&tokens(confirmation)]
    plan=dict(baseline_model_sha256=hashlib.sha256(original_bytes).hexdigest(),
        features_sha256=file_digest(out/'CLEAN_FEATURES.csv'),
        design='Paired 3-fold grouped development comparison on the freshly verified subset of the original 453 target development events. Both arms see identical freshly audited validation-pad features. Baseline is refit using recorded current-training features; candidates train only freshly audited photos. Original 112 confirmation events and related known groups/tokens excluded. Fixed current per-analyte k, metric and transform. No hyperparameter or confidence-threshold search.',
        candidates=['cleaned_current_only','cleaned_plus_legacy'],
        additions='Supplied, complete, non-conflicting specimen references and audited geometry only. Byte/pixel duplicate exports and chart/binary conversions excluded. Same held-out target-group numerical IDs/subject aliases are conservatively excluded from extra-data training across batches.',
        identity_limit='Cross-batch participant identity remains unverified; this is retrospective exploratory development, not a new untouched final evaluation.',
        promotion='Accuracy/macro F1/macro sensitivity/macro specificity and supported rule sensitivity/specificity must not decrease; macro F1 must improve; paired group bootstrap lower accuracy delta must exceed zero. Combined whole-ten accuracy, feature-stage retake coverage and accepted-all-ten accuracy must not regress. Engineering comparison only, not a clinical safety threshold.',
        original_development_events=len(original_development),paired_audited_target_events=len(development),
        target_events_excluded_by_audit=len(original_development)-len(development),
        baseline_confirmation_events_not_evaluated=len(confirmation),
        eligible_new_images=len(new),selection_pool_images=len(safe_pool),abstain_threshold=model['abstain_policy']['threshold'])
    dump(out/'ANALYSIS_PLAN.json',plan)
    folds=[]
    groups=np.array([r['group'] for r in development])
    for tr,va in GroupKFold(3).split(development,groups=groups):
        target_validation=[development[i] for i in va]
        held_groups={r['group'] for r in target_validation}|confirmed_groups
        held_tokens=tokens(target_validation+confirmation)
        extras=[r for r in safe_pool if r['group'] not in held_groups and not tokens([r])&held_tokens]
        train=[r for r in original_development if r['group'] not in held_groups and not tokens([r])&held_tokens]
        assert not {r['image_sha256'] for r in train+extras}&{r['image_sha256'] for r in target_validation}
        folds.append((train,va,extras))
    results={name:dict(prediction=np.empty((len(development),10),dtype=object),confidence=np.zeros((len(development),10)),support=np.zeros((len(development),10),dtype=bool)) for name in ['baseline']+plan['candidates']}
    per_analyte={}; selected={}
    truth=np.array([[r['labels'][a] for a in ANALYTE_ORDER] for r in development])
    for ai,a in enumerate(ANALYTE_ORDER):
        for name,result in results.items():
            for prior,va,extras in folds:
                train=prior if name=='baseline' else [r for r in extras if name=='cleaned_plus_legacy' or r['family']!='RHU175']
                val=[development[i] for i in va]
                prediction,confidence,support=trained_predict(train,val,model['analytes'][a],ai)
                result['prediction'][va,ai]=prediction; result['confidence'][va,ai]=confidence;result['support'][va,ai]=support
            print(f'{a}: evaluated {name}',flush=True)
        base=measure(truth[:,ai],results['baseline']['prediction'][:,ai],groups,a)
        candidates={}
        for name in plan['candidates']:
            value=measure(truth[:,ai],results[name]['prediction'][:,ai],groups,a)
            delta=cluster_delta(truth[:,ai],results['baseline']['prediction'][:,ai],results[name]['prediction'][:,ai],groups)
            candidates[name]=dict(metrics=value,accuracy_delta=delta,engineering_screen=screen(base,value,delta))
        winners=[name for name in candidates if candidates[name]['engineering_screen']['passed']]
        selected[a]=max(winners,key=lambda name:candidates[name]['metrics']['macro_f1_supported_reference_classes']) if winners else 'baseline'
        per_analyte[a]=dict(baseline=base,candidates=candidates,selected=selected[a])
    mixed={key:results['baseline'][key].copy() for key in ['prediction','confidence','support']}
    for ai,a in enumerate(ANALYTE_ORDER):
        for key in mixed:mixed[key][:,ai]=results[selected[a]][key][:,ai]
    base_whole=whole(truth,**results['baseline'],threshold=plan['abstain_threshold'])
    mixed_whole=whole(truth,**mixed,threshold=plan['abstain_threshold'])
    joint_reasons=[]
    for key in ['individual_accuracy','all_ten_accuracy','feature_stage_accepted_all_ten_accuracy']:
        old,new_value=base_whole[key],mixed_whole[key]
        if old is not None and (new_value is None or new_value<old-1e-12): joint_reasons.append(f'{key} decreased')
    if mixed_whole['feature_stage_retake_rate']>base_whole['feature_stage_retake_rate']+1e-12:joint_reasons.append('Feature-stage retake rate increased')
    if all(v=='baseline' for v in selected.values()):joint_reasons.append('No analyte passed the predeclared paired engineering screen')
    report=dict(plan=plan,per_analyte=per_analyte,baseline_whole=base_whole,selected_whole=mixed_whole,
        selected=selected,joint_engineering_screen=dict(passed=not joint_reasons,reasons=joint_reasons),
        production_modified=False,confirmation_evaluated=False)
    dump(out/'DEVELOPMENT_COMPARISON.json',report)
    # Candidate artifacts only. Integrating the app requires this screen and a
    # separate numerical Dart parity check, source freeze and versioned APK.
    if not joint_reasons:
        candidate=copy.deepcopy(model)
        candidate['model_version']='direction_verified_experimental_legacy_v2_20261013'
        candidate['pad_order_verification']['training_features']='legacy_dataset_audit_2026-10-13/CLEAN_FEATURES.csv plus unchanged direction-verified baseline vectors'
        for ai,a in enumerate(ANALYTE_ORDER):
            recipe=selected[a]
            if recipe=='baseline':continue
            training=[r for r in pool if recipe=='cleaned_plus_legacy' or r['family']!='RHU175']
            candidate['analytes'][a]=export_spec(training,model['analytes'][a],ai)
        candidate['legacy_integration']=dict(selected=selected,source_audit='legacy_dataset_audit_2026-10-13',
            engineering_comparison_only=True,clinical_validation_established=False)
        payload=(json.dumps(candidate,indent=2,allow_nan=False)+'\n').encode()
        (out/'CANDIDATE_MODEL.json').write_bytes(payload)
        dump(out/'CANDIDATE_SUPPORT_POLICY.json',build_policy(payload))
    assert MODEL.read_bytes()==original_bytes,'Current production asset changed during experiment'
    print(json.dumps(dict(selected=selected,joint_engineering_screen=report['joint_engineering_screen'],baseline_whole=base_whole,selected_whole=mixed_whole),indent=2),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,default=DEFAULT_OUT)
    run(parser.parse_args().out)
