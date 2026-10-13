"""Public aggregate results and private pad-review crops; no model promotion."""
import csv
import html
import json
import platform
from pathlib import Path
from collections import Counter
import cv2
import numpy as np
import sklearn

from audit_legacy_dataset import ROOT, dump, file_digest
from evaluate_legacy_expansion import baseline_data, tokens
from evaluate_runtime_metric_knn import link_identity_tokens, conservative_group, KEYS
from semiquant_schema import ANALYTE_ORDER

BASE = ROOT / 'pipeline/output/knn_runtime_metric_2026-10-13'
GUARDED = ROOT / 'pipeline/output/knn_runtime_metric_2026-10-13_rule_guarded'
ORDINAL = ROOT / 'pipeline/output/knn_runtime_metric_2026-10-13_ordinal'
OLD = ROOT / 'pipeline/output/legacy_dataset_audit_2026-10-13'


def show(value, percent=True):
    return 'undefined' if value is None else f'{value * 100:.2f}%' if percent else f'{value:.4f}'


def main():
    plan = json.loads((BASE / 'ANALYSIS_PLAN.json').read_text())
    assert file_digest(ROOT / 'uritect_app/assets/production_semiquant_model.json') == plan['installed_classifier_sha256']
    integrity = json.loads((BASE / 'SOURCE_INTEGRITY.json').read_text())
    assert integrity['all_checked_unchanged']
    for folder in [BASE, GUARDED, ORDINAL]:
        results = json.loads((folder / 'RESULTS.json').read_text())
        lines = [f'# Runtime-consistent k-NN development: {folder.name}', '',
                 '**No classifier was promoted or installed. These are exploratory development results.**', '',
                 'The current Dart detector rechecked 210 retained photographs: 188 geometric passes and 22 exclusions pending review. After conservative cross-batch participant-token grouping, known-alias linkage and removal of inspected-confirmation tokens, the safe training pool contained 77 photos; the paired comparison used 70 development photos from 47 inferred groups. The original 112 confirmation events were not evaluated again. Identities remain provisional.', '',
                 'Each outer group fold selected settings using only inner training/validation folds. Training-only scaling, within-class shrinkage distance, raw/normalized circular hue and saturation/value combinations were compared. Reference labels were unchanged. Sensitivity/specificity below are macro one-versus-rest category metrics, not disease-detection performance. Kappa is a coefficient. Absent categories cannot support a sensitivity claim.', '',
                 '| Analyte | Arm | Accuracy | Macro F1 | Macro sensitivity | Macro specificity | Cohen’s kappa |',
                 '|---|---|---:|---:|---:|---:|---:|']
        for analyte, item in results['per_analyte'].items():
            for arm in ['baseline', 'runtime_fixed', 'nested_candidate']:
                m = item['metrics'][arm]
                lines.append('| ' + analyte + ' | ' + arm + ' | ' + ' | '.join(show(m[k], k != 'cohens_kappa') for k in KEYS) + ' |')
        lines += ['', '## Whole-scan development comparison', '',
                  '| Arm | Individual-analyte accuracy | All-ten accuracy | Feature-stage retake rate | All-ten accuracy among accepted scans |',
                  '|---|---:|---:|---:|---:|']
        for arm, m in results['whole_scan'].items():
            lines.append('| ' + arm + ' | ' + ' | '.join(show(m[k]) for k in ['individual_accuracy', 'all_ten_accuracy', 'feature_stage_retake_rate', 'feature_stage_accepted_all_ten_accuracy']) + ' |')
        lines += ['', 'Feature-stage acceptance assumes known localization. It is not actual camera/gallery acceptance, measured phone latency, clinical accuracy or an untouched final evaluation. These percentages must not replace historical figures from different photo cohorts. The baseline is a development-only refit using recorded classifier settings; it is not a test of the installed model fitted on all its data.', '',
                  '## Decisions', '']
        for analyte, item in results['per_analyte'].items():
            lines.append('- **' + analyte + ':** ' + '; '.join(item['promotion_screen']['reasons']) + '.')
        lines += ['', 'No candidate passed promotion. The first broad comparison improved some individual categories but worsened all-ten accuracy. The rule-constrained follow-up retained baseline when inner-fold all-five/rule criteria failed, but outer-fold pH still regressed. Urobilinogen, ketone and bilirubin showed promising category gains; uncertainty, recipe instability or threshold-specific errors prevent treating those gains as established app improvements. Ordered-level aggregation did not improve pH/SG.', '',
                  'The paired pH references contain 53 at 5.0, 15 at 6.0, one at 7.0 and one at 8.5; there are no 6.5 references in this cohort. Nitrite has only two positive photos. Repeated images and synthetic perturbations cannot establish independent rare-category performance.', '',
                  'Next useful work is traceable review of pH/SG pad crops and their original reference readings, followed by checking the exact bottle chart and controlled calibration. Correct verified label/localization mistakes only with source evidence. More tuning on this inspected cohort is not independent confirmation. No labels were guessed, confidence threshold lowered, originals deleted or binary values modified.', '',
                  '[Machine-readable results](RESULTS.json) · [Five-metric CSV](FIVE_METRICS.csv) · [Analysis plan](ANALYSIS_PLAN.json)', '']
        (folder / 'REPORT.md').write_text('\n'.join(lines), encoding='utf-8')
        dump(folder / 'VERIFICATION.json', dict(
            installed_classifier_unchanged=True, protected_files_unchanged=201,
            runtime_photos_checked=210, runtime_geometry_passed=188,
            experimental_guard_tests_passed=4, unit_test_command='python -m unittest discover -s pipeline -p test_runtime_metric_knn.py',
            source_hashes={name: file_digest(ROOT / 'pipeline' / name) for name in ['prepare_runtime_metric_experiment.py', 'evaluate_runtime_metric_knn.py', 'test_runtime_metric_knn.py']},
            environment=dict(python=platform.python_version(), numpy=np.__version__, sklearn=sklearn.__version__),
            confirmation_set_reused=False, clinical_validation_established=False, candidate_promoted=False))

    refs = json.loads((OLD / 'FINAL_PHOTO_AUDIT.json').read_text())
    mapping = {r['image_sha256']: r for r in refs}
    original = baseline_data()
    for r in original:
        r['subject_alias'] = mapping.get(r['image_sha256'], {}).get('subject_alias', '')
    link_identity_tokens(original + refs)
    confirmation = [r for r in original if r['split'] == 'confirmation']
    held = {conservative_group(r) for r in confirmation}
    held_tokens = tokens(confirmation)
    eligible = {r['image_sha256']: r for r in refs if r['status'] == 'accepted_training' and conservative_group(r) not in held and not tokens([r]) & held_tokens
                and json.loads((BASE / 'runtime_detector' / (r['image_sha256'] + '.json')).read_text()).get('geometry_passed')}
    target = [eligible[r['image_sha256']] for r in original if r['split'] == 'development' and r['image_sha256'] in eligible and r['labels'] == eligible[r['image_sha256']]['labels']]
    predictions = json.loads((ORDINAL / 'PRIVATE_PREDICTIONS.json').read_text())
    assert [[r['labels'][a] for a in ANALYTE_ORDER] for r in target] == predictions['truth']
    folder = ORDINAL / 'image_evidence'; folder.mkdir(exist_ok=True)
    rows = []
    for i, row in enumerate(target):
        key = row['image_sha256']
        runtime = json.loads((BASE / 'runtime_detector' / (key + '.json')).read_text())
        image = cv2.imread(str(BASE / 'runtime_detector' / (key + '.frame.png')))
        for ai, analyte in [(4, 'pH'), (6, 'Specific Gravity')]:
            truth = predictions['truth'][i][ai]
            baseline = predictions['predictions']['baseline'][i][ai]
            candidate = predictions['predictions']['nested_candidate'][i][ai]
            if baseline == truth and candidate == truth:
                continue
            x, y, w, h = runtime['rois'][analyte]
            name = f'{key}_{ai}.png'
            assert cv2.imwrite(str(folder / name), image[y:y+h, x:x+w])
            rows.append(dict(image_sha256=key, analyte=analyte, reference=truth, baseline=baseline, candidate=candidate,
                             crop='image_evidence/' + name, review_status='PENDING_SOURCE_REFERENCE_REVIEW'))
    with (ORDINAL / 'PRIVATE_ERROR_REVIEW.csv').open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0])); writer.writeheader(); writer.writerows(rows)
    table = ''.join('<tr><td><img src="' + html.escape(r['crop']) + '" width="100"></td>' + ''.join('<td>' + html.escape(str(r[k])) + '</td>' for k in ['analyte', 'reference', 'baseline', 'candidate', 'review_status']) + '</tr>' for r in rows)
    (ORDINAL / 'PRIVATE_ERROR_REVIEW.html').write_text('<!doctype html><meta charset="utf-8"><title>pH/SG reference review</title><style>body{font:16px system-ui;margin:24px}td,th{padding:12px;border-bottom:1px solid #ddd}img{image-rendering:auto}</style><h1>pH and SG: inspect references before changing labels</h1><p>Current-detector crops; supplied reference categories are not independently reverified. No labels changed.</p><table><tr><th>Crop</th><th>Analyte</th><th>Reference</th><th>Baseline</th><th>Candidate</th><th>Review status</th></tr>' + table + '</table>', encoding='utf-8')
    print('Wrote three aggregate reports and', len(rows), 'private crop-review entries. No model promoted.')


if __name__ == '__main__':
    main()
