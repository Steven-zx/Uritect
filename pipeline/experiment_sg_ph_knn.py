"""Nested, inferred-identity grouped development experiment; never export a model."""
import hashlib
import json
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from sklearn.metrics import accuracy_score, cohen_kappa_score, confusion_matrix, f1_score
from sklearn.model_selection import StratifiedGroupKFold
from threadpoolctl import threadpool_limits

from audit_abnormal_detection import inferred_identity
from freeze_production_semiquant import DEFAULT_DEDUPED, DEFAULT_OPT, _load_rows, _make_model, _rows_for_analyte
from semiquant_schema import ANALYTE_LEVEL_SCHEMA

OUT = Path(__file__).parent / 'output' / 'sg_ph_development_2026-10-10'


def augment(x, y):
    # A deliberately small heuristic, not a validated illumination simulator.
    # Never change hue or labels. Synthetic rows are not independent specimens.
    low, high = x.copy(), x.copy()
    low[:, 1:] = np.clip(low[:, 1:] * np.array([.99, .98]), 0, 1)
    high[:, 1:] = np.clip(high[:, 1:] * np.array([1.01, 1.02]), 0, 1)
    return np.concatenate([x, low, high]), np.tile(y, 3)


def predict(config, x, y, indices, target):
    tx, ty = x[indices], y[indices]
    if config['augmentation']:
        tx, ty = augment(tx, ty)
    model = _make_model(config['k'], config['metric'], config['transform'])
    model.steps[-1][1].set_params(weights=config['weights'], n_jobs=1)
    return model.fit(tx, ty).predict(x[target])


def metrics(y, predicted, labels):
    matrix = confusion_matrix(y, predicted, labels=labels)
    recalls, specificities = [], []
    per_class = {}
    for i, label in enumerate(labels):
        tp = int(matrix[i, i]); fn = int(matrix[i].sum()-tp)
        fp = int(matrix[:, i].sum()-tp); tn = int(matrix.sum()-tp-fn-fp)
        sensitivity = tp/(tp+fn) if tp+fn else None
        specificity = tn/(tn+fp) if tn+fp else None
        if sensitivity is not None: recalls.append(sensitivity)
        if specificity is not None: specificities.append(specificity)
        per_class[label] = dict(support=tp+fn, sensitivity=sensitivity, specificity=specificity, tp=tp, fn=fn, fp=fp, tn=tn)
    return dict(accuracy=float(accuracy_score(y, predicted)), macro_f1=float(f1_score(y, predicted, labels=labels, average='macro', zero_division=0)), macro_sensitivity=float(np.mean(recalls)), macro_specificity=float(np.mean(specificities)), cohen_kappa=float(cohen_kappa_score(y, predicted)), class_metrics=per_class, confusion_matrix=dict(labels=labels, matrix=matrix.tolist()))


def main():
    rows = _load_rows(DEFAULT_DEDUPED)
    frozen = json.loads(DEFAULT_OPT.read_text())
    report = dict(generated_at=datetime.now(timezone.utc).isoformat(), features_sha256=hashlib.sha256(DEFAULT_DEDUPED.read_bytes()).hexdigest(), design='Three outer folds; three inner folds. StratifiedGroupKFold(shuffle=True). Group = batch plus filename-inferred participant identity, grouping lighting and repeated specimens. Provisional identity only; cross-batch identity unverified. All current data are development data. Selection uses inner macro F1, with inner accuracy as tie-breaker. Outer predictions never select candidates.', augmentation='Training only: two extra copies per row, saturation multiplied by .99/1.01 and value by .98/1.02, bounded to [0,1]. Hue unchanged. Heuristic, not demonstrated label-preserving physical lighting variation; not additional biological data.', metrics='Macro F1 includes all seven schema classes with zero for undefined F1, including unrepresented SG 1.000 and pH 8.0. This convention differs from the historical union-of-observed/predicted-label report. Sensitivity/specificity averages exclude undefined denominators and class support is exposed. No quality/confidence/distance filtering. Exact semiquantitative categories, not disease detection.', production_changed=False, analytes={})
    for analyte in ('Specific Gravity', 'pH'):
        subset = [r for r in rows if r['analyte'] == analyte]
        x, y, _, _ = _rows_for_analyte(subset, analyte)
        x, y = np.asarray(x), np.asarray(y)
        assert len(x) == len(subset) and np.isfinite(x).all()
        groups = np.array([inferred_identity(r) for r in subset])
        p = frozen[analyte]
        base = dict(k=p['best_k'], metric=p['best_metric'], transform=p['feature_transform'], weights='distance', augmentation=False)
        candidates = [base]
        for k in (3, 7, 15, 31):
            for metric in ('euclidean', 'chebyshev'):
                for weights in ('distance', 'uniform'):
                    c = dict(k=k, metric=metric, transform='circular_scaled', weights=weights, augmentation=False)
                    if c not in candidates: candidates.append(c)
        # Matched baseline controls, including k adjusted for 3x row replication.
        candidates += [dict(base, augmentation=True), dict(base, augmentation=True, k=base['k']*3)]
        result = dict(n=len(y), inferred_groups=len(set(groups)), class_counts=dict(Counter(y)), class_identity_counts={label:len(set(groups[y==label])) for label in ANALYTE_LEVEL_SCHEMA[analyte]}, candidates=candidates, folds=[])
        outputs = {name: np.empty(len(y), dtype=object) for name in ('baseline','matched_baseline_augmentation','tuning_without_augmentation','tuning_with_augmentation')}
        outer = StratifiedGroupKFold(n_splits=3, shuffle=True, random_state=42)
        for fold, (tr, va) in enumerate(outer.split(x,y,groups)):
            assert set(groups[tr]).isdisjoint(groups[va])
            inner = list(StratifiedGroupKFold(n_splits=3, shuffle=True, random_state=100+fold).split(x[tr],y[tr],groups[tr]))
            scores = []
            for ci, candidate in enumerate(candidates):
                values = []
                for itr, iva in inner:
                    assert set(groups[tr[itr]]).isdisjoint(groups[tr[iva]])
                    pred = predict(candidate,x,y,tr[itr],tr[iva])
                    values.append((float(f1_score(y[tr[iva]],pred,labels=ANALYTE_LEVEL_SCHEMA[analyte],average='macro',zero_division=0)),float(accuracy_score(y[tr[iva]],pred))))
                scores.append(dict(candidate=ci, macro_f1=float(np.mean([v[0] for v in values])), accuracy=float(np.mean([v[1] for v in values]))))
            def best(allowed):
                return max(allowed,key=lambda i:(scores[i]['macro_f1'],scores[i]['accuracy'],-i))
            chosen = {'baseline':0, 'tuning_without_augmentation':best([i for i,c in enumerate(candidates) if not c['augmentation']]), 'tuning_with_augmentation':best(range(len(candidates)))}
            fold_result = dict(fold=fold+1,train_rows=len(tr),validation_rows=len(va),validation_class_counts=dict(Counter(y[va])),inner_scores=scores,selected=chosen,outer_metrics={})
            for name,ci in chosen.items():
                pred = predict(candidates[ci],x,y,tr,va)
                outputs[name][va] = pred
                fold_result['outer_metrics'][name] = metrics(y[va],pred,ANALYTE_LEVEL_SCHEMA[analyte])
            # Evaluate augmentation matched to baseline without selection on outer data.
            matched = predict(dict(base,augmentation=True),x,y,tr,va)
            outputs['matched_baseline_augmentation'][va] = matched
            fold_result['matched_augmentation_metrics'] = metrics(y[va],matched,ANALYTE_LEVEL_SCHEMA[analyte])
            result['folds'].append(fold_result)
            print(analyte,'fold',fold+1,'complete',flush=True)
        result['out_of_fold_metrics'] = {name:metrics(y,pred,ANALYTE_LEVEL_SCHEMA[analyte]) for name,pred in outputs.items()}
        report['analytes'][analyte] = result
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'experiment.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
    lines = ['# Specific gravity and pH development experiment', '', report['design'], '', report['augmentation'], '', report['metrics'], '', '| Analyte | Procedure | Accuracy | Macro F1 | Macro sensitivity | Macro specificity | Kappa |', '| --- | --- | ---: | ---: | ---: | ---: | ---: |']
    for analyte,result in report['analytes'].items():
        for name,m in result['out_of_fold_metrics'].items():
            lines.append(f"| {analyte} | {name} | {m['accuracy']:.2%} | {m['macro_f1']:.2%} | {m['macro_sensitivity']:.2%} | {m['macro_specificity']:.2%} | {m['cohen_kappa']:.4f} |")
    lines += ['', 'These scores use a different grouping/split from historical 58.90% SG and 81.60% pH. Compare baseline versus candidate procedures within this experiment only. No deployable model is selected or exported. Nested evaluation describes a tuning procedure whose folds can select different configurations. Independent adjudicated specimens and physical-image/runtime validation remain required before promotion.', '', '## Data and next experiments', '']
    for analyte,result in report['analytes'].items():
        lines += [analyte+' capture counts: '+str(result['class_counts']), '', analyte+' provisional identity counts: '+str(result['class_identity_counts']), '']
    lines += ['pH 8.5 has only two inferred identities and four captures. Three-fold inner stratification emitted rare-class warnings; some partitions cannot contain every class. SG 1.000 and pH 8.0 have no examples. Do not claim performance for these absent levels.', '', 'Matched small S/V augmentation is an ablation, not proof of physically correct color changes. No hue jitter, SMOTE or synthetic class creation was used. More aggressive color augmentation requires actual repeated captures under known conditions to establish label preservation.', '', 'Priorities: verify participant/specimen identities and exact-strip category mappings; collect independent reference-adjudicated examples of rare/missing pH levels; review pad crops, reading time and lighting for SG adjacent-level mistakes. Extract aligned crop/illumination features from verified original images before proposing a different feature representation. Re-run grouped development evaluation and then an untouched independent final evaluation. The slight SG gain and pH accuracy/F1 trade-off do not justify replacing the current production model.', '', 'Full fold scores, selected settings, class supports and confusion matrices: experiment.json.', '']
    (OUT/'REPORT.md').write_text('\n'.join(lines))
    print('Report:',OUT/'REPORT.md',flush=True)


if __name__ == '__main__':
    with threadpool_limits(limits=1):
        main()
