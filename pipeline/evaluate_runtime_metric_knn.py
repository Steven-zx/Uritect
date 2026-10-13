"""Nested, conservative-group development comparison; never edits app assets."""
import csv
import argparse
import json
from pathlib import Path
from collections import Counter
import numpy as np
from scipy.spatial.distance import cdist
from sklearn.model_selection import GroupKFold
from sklearn.neighbors import KNeighborsClassifier
from sklearn.preprocessing import StandardScaler
from threadpoolctl import threadpool_limits

from audit_legacy_dataset import ROOT, dump, file_digest
from evaluate_legacy_expansion import baseline_data, tokens, trained_predict, cluster_delta, whole
from freeze_production_semiquant import _make_model
from improve_direction_verified_knn import measure
from model_features import hsv_to_circular_features
from semiquant_schema import ANALYTE_ORDER

OUT = ROOT / 'pipeline/output/knn_runtime_metric_2026-10-13'
RUNTIME = OUT / 'runtime_detector'
OLD = ROOT / 'pipeline/output/legacy_dataset_audit_2026-10-13'
MODEL = ROOT / 'uritect_app/assets/production_semiquant_model.json'
KEYS = ['accuracy', 'macro_f1_supported_reference_classes', 'macro_sensitivity', 'macro_specificity', 'cohens_kappa']
LIMIT = threadpool_limits(limits=1)
IDENTITY_ROOTS = {}
RULE_CONSTRAINED = False
ORDINAL_TARGETS = False


def conservative_group(row):
    identifiers = tokens([row])
    return 'token:' + IDENTITY_ROOTS.get(min(identifiers), min(identifiers)) if identifiers else row['group']


def link_identity_tokens(rows):
    parent = {}
    def root(value):
        parent.setdefault(value, value)
        if parent[value] != value:
            parent[value] = root(parent[value])
        return parent[value]
    for row in rows:
        values = sorted(tokens([row]))
        for value in values[1:]:
            a, b = root(values[0]), root(value)
            parent[max(a, b)] = min(a, b)
        if values:
            root(values[0])
    IDENTITY_ROOTS.clear()
    IDENTITY_ROOTS.update({value: root(value) for value in parent})


def nonregression(base, value):
    return all(base[k] is not None and value[k] is not None and value[k] >= base[k] - 1e-12 for k in KEYS)


def ranking(m):
    return .45 * m['macro_f1_supported_reference_classes'] + .30 * (m['macro_sensitivity'] or 0) + .15 * m['accuracy'] + .10 * (m['macro_specificity'] or 0)


def rules_nonregression(base, value):
    for rule, old in base['reference_label_thresholds'].items():
        new = value['reference_label_thresholds'][rule]
        for key in ['sensitivity', 'specificity']:
            if old[key] is not None and (new[key] is None or new[key] < old[key] - 1e-12):
                return False
    return True


def recipe(rows, ai, kind):
    norm = np.array([r['features'][ai] for r in rows])
    raw = np.array([r['raw_features'][ai] for r in rows])
    n, r = hsv_to_circular_features(norm), hsv_to_circular_features(raw)
    return {'normalized': n, 'raw': r, 'normalized_hs': n[:, :3], 'raw_hs': r[:, :3],
            'joined': np.column_stack([n, r])}[kind]


def predict_config(train, validation, config, ai, support=False):
    tx = recipe(train, ai, config['recipe'])
    vx = recipe(validation, ai, config['recipe'])
    y = np.array([r['labels'][ANALYTE_ORDER[ai]] for r in train])
    scaler = StandardScaler().fit(tx)
    tx, vx = scaler.transform(tx), scaler.transform(vx)
    if config['geometry'] == 'within_class':
        # Learn a shrinkage metric from training residuals only, never validation.
        residual = np.vstack([tx[y == c] - tx[y == c].mean(axis=0) for c in np.unique(y)])
        covariance = residual.T @ residual / max(1, len(tx) - len(np.unique(y)))
        covariance = .8 * covariance + .2 * np.diag(np.diag(covariance)) + np.eye(tx.shape[1]) * .05
        matrix = np.linalg.inv(np.linalg.cholesky(covariance)).T
        tx, vx = tx @ matrix, vx @ matrix
    estimator = KNeighborsClassifier(n_neighbors=min(config['k'], len(tx)), weights='distance', metric=config['metric'], algorithm='brute', n_jobs=1).fit(tx, y)
    probabilities = estimator.predict_proba(vx)
    aggregation = config.get('aggregation', 'class_vote')
    if aggregation == 'ordinal_mean':
        levels = estimator.classes_.astype(float)
        selected = np.abs((probabilities @ levels)[:, None] - levels[None, :]).argmin(axis=1)
    elif aggregation == 'ordinal_median':
        order = np.argsort(estimator.classes_.astype(float))
        selected = order[(np.cumsum(probabilities[:, order], axis=1) >= .5).argmax(axis=1)]
    else:
        selected = probabilities.argmax(axis=1)
    prediction = estimator.classes_[selected]
    accepted = np.ones(len(validation), dtype=bool)
    if support:
        unique = np.unique(tx, axis=0)
        metric = 'cityblock' if config['metric'] == 'manhattan' else config['metric']
        if len(unique) < 2:
            accepted[:] = False
        else:
            distances = cdist(unique, unique, metric=metric)
            np.fill_diagonal(distances, np.inf)
            radius = distances.min(axis=1).max()
            accepted = cdist(vx, tx, metric=metric).min(axis=1) <= radius + 1e-10
    # Confidence belongs to the selected category, including ordinal choices.
    return prediction, probabilities[np.arange(len(validation)), selected], accepted


CONFIGS = [dict(recipe=recipe_name, geometry=geometry, k=k, metric=metric)
           for recipe_name in ['normalized', 'raw', 'normalized_hs', 'raw_hs', 'joined']
           for geometry in ['scaled', 'within_class'] for k in [1, 3, 5, 7]
           for metric in ['euclidean', 'manhattan']]


def select_config(train, old_train, spec, ai):
    groups = np.array([r['evaluation_group'] for r in train])
    folds = list(GroupKFold(min(3, len(set(groups)))).split(train, groups=groups))
    truth = np.array([r['labels'][ANALYTE_ORDER[ai]] for r in train])
    baseline_prediction = np.empty(len(train), dtype=object)
    for tr, va in folds:
        held = {groups[i] for i in va}
        prior = [r for r in old_train if r['evaluation_group'] not in held]
        baseline_prediction[va] = trained_predict(prior, [train[i] for i in va], spec, ai)[0]
    baseline = measure(truth, baseline_prediction, groups, ANALYTE_ORDER[ai])
    if ORDINAL_TARGETS and ANALYTE_ORDER[ai] not in ['pH', 'Specific Gravity']:
        return dict(config=None, metrics=baseline, all_five_nonregression=True, objective=ranking(baseline)), baseline
    configurations = CONFIGS
    if ORDINAL_TARGETS:
        configurations = [dict(c, aggregation=aggregation) for c in CONFIGS
                          for aggregation in ['class_vote', 'ordinal_mean', 'ordinal_median']]
    scores = []
    for config in configurations:
        predictions = np.empty(len(train), dtype=object)
        for tr, va in folds:
            predictions[va] = predict_config([train[i] for i in tr], [train[i] for i in va], config, ai)[0]
        value = measure(truth, predictions, groups, ANALYTE_ORDER[ai])
        scores.append(dict(config=config, metrics=value, all_five_nonregression=nonregression(baseline, value), objective=ranking(value)))
    preferred = [s for s in scores if s['all_five_nonregression'] and s['metrics']['macro_f1_supported_reference_classes'] > baseline['macro_f1_supported_reference_classes']]
    if RULE_CONSTRAINED:
        preferred = [s for s in preferred if rules_nonregression(baseline, s['metrics'])]
        if not preferred:
            return dict(config=None, metrics=baseline, all_five_nonregression=True, objective=ranking(baseline)), baseline
    winner = max(preferred or scores, key=lambda r: (r['objective'], r['metrics']['accuracy'], -r['config']['k']))
    return winner, baseline


def main():
    global OUT, RULE_CONSTRAINED, ORDINAL_TARGETS
    parser = argparse.ArgumentParser()
    parser.add_argument('--rule-constrained', action='store_true')
    parser.add_argument('--ordinal-targets', action='store_true')
    args = parser.parse_args()
    ORDINAL_TARGETS = args.ordinal_targets
    RULE_CONSTRAINED = args.rule_constrained or ORDINAL_TARGETS
    if RULE_CONSTRAINED:
        previous = OUT
        suffix = 'ordinal' if ORDINAL_TARGETS else 'rule_guarded'
        OUT = ROOT / ('pipeline/output/knn_runtime_metric_2026-10-13_' + suffix)
        OUT.mkdir(exist_ok=True)
        plan = json.loads((previous / 'ANALYSIS_PLAN.json').read_text())
        plan.update(selection='Inner-fold all-five metric and supported abnormal-rule sensitivity/specificity nonregression; macro F1 must improve. Otherwise retain the recorded baseline recipe. No permissive trade-off winner.',
                    reason_for_followup='First nested development comparison increased pooled accuracy but reduced all-ten accuracy and abnormal-rule specificity. This is another inspected development experiment, not final-test confirmation.',
                    previous_results_sha256=file_digest(previous / 'RESULTS.json'))
        dump(OUT / 'ANALYSIS_PLAN.json', plan)
        if ORDINAL_TARGETS:
            plan.update(targets=['pH', 'Specific Gravity'],
                        reason_for_followup='18/19 pH baseline errors within 1.0 pH; 16/24 SG errors within 0.005. Test ordered-neighbor aggregation only for these targets; all other analytes retain baseline.',
                        ordered_aggregations=['class_vote', 'ordinal_mean', 'ordinal_median'],
                        ordinal_confidence='Vote probability of the actually selected category, not the maximum probability of another category.',
                        fabricated_categories=False)
            dump(OUT / 'ANALYSIS_PLAN.json', plan)
    assert not (OUT / 'RESULTS.json').exists(), 'Preserve recorded experiments; use a new output folder'
    original_hash = file_digest(MODEL)
    model = json.loads(MODEL.read_text())
    references = json.loads((OLD / 'FINAL_PHOTO_AUDIT.json').read_text())
    original = baseline_data()
    reference_map = {r['image_sha256']: r for r in references}
    for r in original:
        r['subject_alias'] = reference_map.get(r['image_sha256'], {}).get('subject_alias', '')
    link_identity_tokens(original + references)
    for r in original:
        r['evaluation_group'] = conservative_group(r)
    confirmation = [r for r in original if r['split'] == 'confirmation']
    held_groups = {r['evaluation_group'] for r in confirmation}
    held_tokens = tokens(confirmation)
    old_development = [r for r in original if r['split'] == 'development' and r['evaluation_group'] not in held_groups and not tokens([r]) & held_tokens]
    pool, rejected = [], Counter()
    for reference in references:
        if reference['status'] != 'accepted_training':
            continue
        result = json.loads((RUNTIME / (reference['image_sha256'] + '.json')).read_text())
        if not result.get('geometry_passed'):
            rejected[result.get('error', 'unknown').split(':')[0]] += 1
            continue
        row = dict(reference)
        row['evaluation_group'] = conservative_group(row)
        row['features'] = np.array([result['features'][a] for a in ANALYTE_ORDER])
        row['raw_features'] = np.array([result['raw_features'][a] for a in ANALYTE_ORDER])
        assert row['features'].shape == (10, 3)
        assert np.isfinite(row['features']).all() and np.isfinite(row['raw_features']).all()
        if row['evaluation_group'] in held_groups or tokens([row]) & held_tokens:
            continue
        pool.append(row)
    by_hash = {r['image_sha256']: r for r in pool}
    target = [dict(by_hash[r['image_sha256']], event_id=r['event_id']) for r in old_development
              if r['image_sha256'] in by_hash and r['labels'] == by_hash[r['image_sha256']]['labels']]
    groups = np.array([r['evaluation_group'] for r in target])
    plan = json.loads((OUT / 'ANALYSIS_PLAN.json').read_text())
    plan.update(revalidated_geometry_failures=dict(rejected), safe_training_pool=len(pool), paired_target_photos=len(target),
                paired_target_groups=len(set(groups)), original_confirmation_events_excluded=len(confirmation),
                conservative_identity='Merge repeated numeric participant tokens across batches; original inspected confirmation tokens excluded throughout. Different unknown aliases remain a limitation.',
                configurations=CONFIGS, outer_folds=3, inner_folds=3)
    dump(OUT / 'ANALYSIS_PLAN.json', plan)
    assert len(set(groups)) >= 6 and len(target) >= 20, 'Insufficient safely grouped development data'
    folds = list(GroupKFold(3).split(target, groups=groups))
    truth = np.array([[r['labels'][a] for a in ANALYTE_ORDER] for r in target])
    arms = {name: dict(prediction=np.empty(truth.shape, dtype=object), confidence=np.zeros(truth.shape), support=np.zeros(truth.shape, dtype=bool))
            for name in ['baseline', 'runtime_fixed', 'nested_candidate']}
    selection = {}
    for ai, analyte in enumerate(ANALYTE_ORDER):
        selection[analyte] = []
        spec = model['analytes'][analyte]
        for fold, (_, va) in enumerate(folds):
            held = {groups[i] for i in va}
            train = [r for r in pool if r['evaluation_group'] not in held]
            prior = [r for r in old_development if r['evaluation_group'] not in held]
            val = [target[i] for i in va]
            assert not {r['image_sha256'] for r in train + prior} & {r['image_sha256'] for r in val}
            winner, inner_base = select_config(train, prior, spec, ai)
            selection[analyte].append(dict(fold=fold, config=winner['config'], inner_metrics=winner['metrics'], inner_baseline=inner_base,
                                          inner_all_five_nonregression=winner['all_five_nonregression']))
            for name, output in arms.items():
                values = (trained_predict(prior if name == 'baseline' else train, val, spec, ai)
                          if name != 'nested_candidate' else
                          trained_predict(prior, val, spec, ai) if winner['config'] is None else
                          predict_config(train, val, winner['config'], ai, support=True))
                for key, value in zip(['prediction', 'confidence', 'support'], values):
                    output[key][va, ai] = value
        print('Evaluated', analyte, 'with nested group-separated selection', flush=True)
    results = {}
    for ai, analyte in enumerate(ANALYTE_ORDER):
        values = {name: measure(truth[:, ai], arm['prediction'][:, ai], groups, analyte) for name, arm in arms.items()}
        base, candidate = values['baseline'], values['nested_candidate']
        reasons = [k + ' decreased/undefined' for k in KEYS if base[k] is None or candidate[k] is None or candidate[k] < base[k] - 1e-12]
        delta = cluster_delta(truth[:, ai], arms['baseline']['prediction'][:, ai], arms['nested_candidate']['prediction'][:, ai], groups)
        if delta['low'] <= 0:
            reasons.append('Paired group accuracy interval includes zero')
        if candidate['macro_f1_supported_reference_classes'] <= base['macro_f1_supported_reference_classes']:
            reasons.append('No macro F1 improvement')
        for rule, old in base['reference_label_thresholds'].items():
            new = candidate['reference_label_thresholds'][rule]
            for key in ['sensitivity', 'specificity']:
                if old[key] is not None and (new[key] is None or new[key] < old[key] - 1e-12):
                    reasons.append(rule + ' ' + key + ' decreased')
        consistent = len({json.dumps(s['config'], sort_keys=True) for s in selection[analyte]}) == 1
        if not consistent:
            reasons.append('Nested folds selected different recipes; no stable single deployment recipe')
        results[analyte] = dict(metrics=values, accuracy_delta=delta, fold_selection=selection[analyte], promotion_screen=dict(passed=not reasons, reasons=reasons))
    whole_results = {name: whole(truth, **arm, threshold=model['abstain_policy']['threshold']) for name, arm in arms.items()}
    assert file_digest(MODEL) == original_hash
    dump(OUT / 'RESULTS.json', dict(per_analyte=results, whole_scan=whole_results, installed_model_unchanged=True,
                                  scope='Exploratory nested development procedure, not a new untouched final test or evaluation of the installed all-data model. No candidate automatically promoted.'))
    rows = []
    for analyte, result in results.items():
        for name, value in result['metrics'].items():
            rows.append(dict(analyte=analyte, arm=name, n=value['n'], **{k: value[k] for k in KEYS}))
    with (OUT / 'FIVE_METRICS.csv').open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader(); writer.writerows(rows)
    dump(OUT / 'PRIVATE_PREDICTIONS.json', dict(groups=groups.tolist(), truth=truth.tolist(),
                                              predictions={k: v['prediction'].tolist() for k, v in arms.items()}))
    print('Recorded results; installed model unchanged.')


if __name__ == '__main__':
    main()
