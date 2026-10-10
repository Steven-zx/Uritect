"""Check focused audit provenance, grouping, labels and non-promotion evidence."""
import csv
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'pipeline/output/ph_sg_error_audit_2026-10-11'


def main():
    evidence = json.loads((OUT / 'RUN_EVIDENCE.json').read_text())
    for name, expected in evidence['sources'].items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == expected, name
    manifest = json.loads((ROOT / 'pipeline/output/knn_improvement_2026-10-11/SPLIT_MANIFEST.json').read_text())
    events = {r['event_id']: r for r in manifest['events']}
    dev = {e for e, r in events.items() if r['split'] == 'development'}
    confirmation = set(events) - dev
    assert len(dev) == 453 and len(confirmation) == 112
    groups = lambda ids: {events[e]['group'] for e in ids}
    assert not groups(dev) & groups(confirmation)
    coverage = Counter()
    for fold in manifest['folds']:
        tr, va = set(fold['train']), set(fold['validation'])
        assert tr | va == dev and not tr & va
        assert not groups(tr) & groups(va)
        coverage.update(va)
    assert set(coverage.values()) == {1} and set(coverage) == dev
    with (OUT / 'FOCUSED_REVIEW.csv').open(encoding='utf-8') as f:
        review = list(csv.DictReader(f))
    with (OUT / 'NESTED_PREDICTIONS.csv').open(encoding='utf-8') as f:
        pred = list(csv.DictReader(f))
    with (ROOT / 'pipeline/output/knn_improvement_2026-10-11/GROUPED_DATASET.csv').open(encoding='utf-8-sig') as f:
        gold = {(r['event_id'], r['analyte']): r['level'] for r in csv.DictReader(f)}
    assert len(review) == len(pred) == 906
    for records in (review, pred):
        assert len({(r['event_id'], r['analyte']) for r in records}) == 906
        for r in records:
            assert r['event_id'] in dev
            assert r['reference'] == gold[r['event_id'], r['analyte']]
    for r in review:
        for field in ('context', 'crop', 'refined_crop'):
            assert (OUT / r[field]).is_file()
    results = json.loads((OUT / 'NESTED_DEVELOPMENT_RESULTS.json').read_text())
    for result in results.values():
        assert not result['engineering_screen_passed']
        assert result['baseline']['n'] == result['nested_selected']['n'] == 453
    diagnostics = json.loads((OUT / 'ERROR_CAUSE_DIAGNOSTICS.json').read_text())
    for d in diagnostics.values():
        assert d['reference_integrity']['raw_to_canonical_mismatches'] == 0
        assert not d['reference_integrity']['inferred_groups_with_conflicting_reference_labels']
    record = {
        'audit_provenance_and_output_checks': 'passed',
        'development_events': 453,
        'confirmation_events_not_evaluated': 112,
        'reference_labels_unchanged': True,
        'app_classifier_sha256_unchanged': evidence['sources']['uritect_app/assets/production_semiquant_model.json'],
        'candidate_promoted': False,
        'python_tests': {'command': ".venv\\Scripts\\python.exe -m unittest discover -s pipeline -p 'test_*.py'", 'passed': 50},
        'flutter_tests': {'command': 'flutter test --no-pub (uritect_app)', 'passed': 143},
        'static_analysis': {'command': 'flutter analyze --no-pub (repository root)', 'result': 'No issues found', 'exit_code': 0},
        'test_evidence_scope': 'CLI results observed in this work session; test counts are recorded results, not rerun by this verifier.',
        'parity_scope': 'Thirty identical decoded RGB pixel/ROI/gain cases verify feature math; full decoder/detector/new-classifier parity is not claimed.',
        'manual_review': 'Original and regenerated targeted pH/SG contact sheets plus the enlarged Cabatuan_025_Daylight SG context were visually inspected. Sampled review, not exhaustive reference adjudication.',
        'sources': {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in (
            Path(__file__), ROOT / 'pipeline/summarize_ph_sg_audit.py',
            ROOT / 'uritect_app/lib/services/runtime_pad_features.dart',
            ROOT / 'uritect_app/lib/services/local_scan_analysis_service.dart',
            ROOT / 'uritect_app/test/runtime_pad_features_test.dart',
            ROOT / 'uritect_app/test/fixtures/runtime_pad_color_parity.json',
        )},
    }
    (OUT / 'VERIFICATION.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print('Focused audit verified: grouping, source hashes, labels, image links and non-promotion decision.')


if __name__ == '__main__':
    main()
