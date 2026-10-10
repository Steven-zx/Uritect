"""Verify saved experiment evidence without refitting or modifying the app."""
import csv
import hashlib
import json
from pathlib import Path

from semiquant_schema import ANALYTE_ORDER
from specimen_grouping import specimen_group

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'pipeline/output/knn_improvement_2026-10-11'


def load(name):
    return json.loads((OUT/name).read_text(encoding='utf-8'))


def main():
    evidence = load('RUN_EVIDENCE.json')
    for name,expected in evidence['sources'].items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == expected, f'Source drift: {name}'
    assert hashlib.sha256((OUT/'SELECTED_CONFIGURATION.json').read_bytes()).hexdigest() == evidence['configuration_sha256']
    with (ROOT/'pipeline/output/orientation_audit_2026-10-11_v3/candidate_deduped.csv').open(newline='',encoding='utf-8-sig') as f:
        originals = list(csv.DictReader(f))
    with (OUT/'GROUPED_DATASET.csv').open(newline='',encoding='utf-8-sig') as f:
        grouped = list(csv.DictReader(f))
    keys = lambda row:(row['event_id'],row['analyte'])
    assert len(grouped) == len(originals) == len({keys(r) for r in originals}) == 5650
    original_map = {keys(r):r for r in originals}
    for row in grouped:
        assert row['level'] == original_map[keys(row)]['level']
        assert row['specimen_group'] == specimen_group(row)
    manifest = load('SPLIT_MANIFEST.json'); events = {r['event_id']:r for r in manifest['events']}
    development = {e for e,r in events.items() if r['split']=='development'}
    confirmation = set(events)-development
    for field in ('group','image_sha256'):
        assert not {events[e][field] for e in development} & {events[e][field] for e in confirmation}
    all_validation = []
    for fold in manifest['folds']:
        train,validation = set(fold['train']),set(fold['validation'])
        assert train | validation == development and not train & validation
        assert not {events[e]['group'] for e in train} & {events[e]['group'] for e in validation}
        all_validation.extend(validation)
    assert set(all_validation) == development and len(all_validation)==len(development)
    predictions = load('PREDICTIONS.json'); result = load('CONFIRMATION_RESULTS.json')
    failed = set()
    for stage,records in predictions.items():
        expected = development if stage.startswith('development') else confirmation
        assert set(records) == expected
        individual_correct = all_correct = accepted = 0
        for event,rs in records.items():
            assert len(rs)==10 and {r['analyte'] for r in rs} == set(ANALYTE_ORDER)
            correctness = []
            for row in rs:
                assert row['reference'] == original_map[(event,row['analyte'])]['level']
                assert 0 <= row['confidence'] <= 1
                for field in ('pad_crop','context'):
                    path = (OUT/row[field]).resolve()
                    assert path.is_relative_to((OUT/'image_evidence').resolve()) and path.is_file()
                correct = row['reference']==row['prediction']; correctness.append(correct)
                if not correct: failed.add((stage,event,row['analyte']))
            individual_correct += sum(correctness); all_correct += all(correctness)
            accepted += all(r['confidence']>=.55 for r in rs)
        s = result['summary'][stage]
        assert abs(s['individual_accuracy']-individual_correct/(10*len(records))) < 1e-12
        assert abs(s['all_ten_accuracy']-all_correct/len(records)) < 1e-12
        assert abs(s['vote_only_acceptance_rate']-accepted/len(records)) < 1e-12
    with (OUT/'ERROR_REVIEW.csv').open(newline='',encoding='utf-8-sig') as f:
        review = list(csv.DictReader(f))
    assert {(r['stage'],r['event_id'],r['analyte']) for r in review} == failed
    assert all(not r['adjudicated_label'] and not r['reviewer'] for r in review)
    report = dict(status='passed',source_and_app_hashes_verified=True,unchanged_reference_rows=len(grouped),
                  event_count=len(events),development_events=len(development),confirmation_events=len(confirmation),
                  cross_split_group_and_duplicate_image_overlap=0,validation_events_predicted_exactly_once=True,
                  recomputed_summary_metrics=True,all_failed_rows_have_real_local_crop_evidence=True,error_rows=len(review),
                  clinical_validation_established=False)
    (OUT/'ARTIFACT_VERIFICATION.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__':
    main()
