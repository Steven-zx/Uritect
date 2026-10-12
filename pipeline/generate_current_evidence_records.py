"""Bind current evaluation records to the sealed APK; keep absent evidence pending."""
import csv
import argparse
import json
import re
from pathlib import Path
from build_final_release_manifest import ROOT, entry
from verify_release_acceptance import REQUIRED_CASES


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--evidence-dir', type=Path)
    args = parser.parse_args()
    version = re.search(r'^version:\s*(\S+)', (ROOT / 'uritect_app/pubspec.yaml').read_text(), re.M)[1]
    candidates = list((ROOT / 'output/device_pilot').glob('*/' + version))
    assert args.evidence_dir or len(candidates) == 1, 'Select one sealed evidence folder'
    folder = args.evidence_dir.resolve() if args.evidence_dir else candidates[0]
    assert folder.is_relative_to(ROOT / 'output/device_pilot')
    receipt = json.loads((folder / 'EVALUATION_BUILD.json').read_text())
    assert receipt['version'] == version, 'Build receipt version mismatch'
    apk = ROOT / receipt['apk']
    assert receipt['sha256'] == entry(apk)['sha256']
    strip = json.loads((ROOT / 'docs/URITECT_PHYSICAL_STRIP_RECORD.json').read_text())
    model = json.loads((ROOT / 'uritect_app/assets/production_semiquant_model.json').read_text())
    release = {
        'schema_version': 1, 'version': version,
        'status': 'signed_research_candidate_pending_device_and_external_evidence',
        'apk': entry(apk), 'build_receipt': entry(folder / 'EVALUATION_BUILD.json'),
        'source_snapshot': entry(folder / 'SOURCE_SNAPSHOT.json'),
        'source_archive': entry(folder / 'URITECT_SOURCE_SNAPSHOT.zip'),
        'model': entry(ROOT / 'uritect_app/assets/production_semiquant_model.json'),
        'model_version': model['model_version'],
        'clinical_validation_established': False,
        'strip_record': entry(ROOT / 'docs/URITECT_PHYSICAL_STRIP_RECORD.json'),
        'acceptance_record': 'docs/URITECT_CURRENT_ACCEPTANCE_RECORD.json',
        'gap_response': 'docs/URITECT_EVIDENCE_GAP_REMEDIATION_2026-10-12.md',
        'historical_manifest': 'output/release/URITECT_FINAL_RELEASE_MANIFEST.json',
        'historical_manifest_is_current': False,
        'note': 'Byte/hash identity is verified, not byte-for-byte reproducible rebuilds or clinical validity.',
    }
    record_path = ROOT / 'docs/URITECT_CURRENT_ACCEPTANCE_RECORD.json'
    old = json.loads(record_path.read_text()) if record_path.exists() else None
    if old and old['release'] != version:
        assert re.fullmatch(r'\d+\.\d+\.\d+\+\d+', old['release'])
        previous_folders = list((ROOT / 'output/device_pilot').glob('*/' + old['release']))
        assert len(previous_folders) == 1, 'Locate the prior build evidence uniquely'
        previous = previous_folders[0] / 'ACCEPTANCE_RECORD.json'
        assert previous.parent.exists(), 'Prior build evidence folder must exist'
        if previous.exists():
            assert json.loads(previous.read_text()) == old, 'Preserve differing prior observations'
        else:
            write(previous, old)
        old = None
    if old:
        record = old
    else:
        physical = {
            'status': 'partially_recorded_pending_signed_ifu_review',
            'manufacturer': strip['manufacturer'], 'product': strip['product'],
            'catalogue_number': strip['catalogue_number'], 'lot': strip['lot'],
            'manufacture_date': strip['manufacture_date'], 'expiry': strip['expiry_date'],
            'opening_date': strip['opening_date'], 'storage_conditions': strip['storage_conditions'],
            'ifu_revision': strip['ifu_revision'], 'ifu_evidence': strip['ifu_evidence'],
            'pad_order': strip['physical_pad_order'],
            'categories': strip['manufacturer_chart_categories'],
            'reading_times_seconds': strip['reading_times_seconds'],
            'timing_strategy_matches_app': None, 'reviewers': [],
            'anti_vc_claim_verified': False,
        }
        record = {
            'schema_version': 1, 'release': version, 'status': 'pending_actual_evaluation',
            'clinical_calibration_status': 'not_established',
            'devices': [{
                'device_id': f'phone_{i+1}', 'model': 'RMX3933' if i == 0 else None,
                'android_version': None, 'test_date': None, 'tester': None,
                'apk_sha256': receipt['sha256'], 'connection_status': 'not_connected',
                'cases': [{'id': key, 'expected': text, 'actual': None,
                           'status': 'PENDING', 'evidence': [], 'input_sha256': []}
                          for key, text in REQUIRED_CASES.items()],
                'scan_latency_seconds': [], 'crashes': None, 'hangs': None,
            } for i in range(2)],
            'physical_strip': physical,
            'reviews': {key: {'status': 'pending', 'reviewer': None, 'credentials': None,
                             'repository_commit_release_tag_or_version_reviewed': None,
                             'date': None, 'apk_sha256': receipt['sha256'],
                             'decisions': [], 'evidence': []}
                        for key in ['medtech_1','medtech_2','medtech_3','physician','statistician','usability_evaluation']},
            'manuscript': {'status': 'pending_editable_source_and_actual_revision', 'evidence': []},
            'clinical_outcome_study': {'status': 'not_performed', 'evidence': []},
        }
    write(record_path, record)
    write(ROOT / 'docs/CURRENT_EVALUATION_RELEASE.json', release)
    checklist = ROOT / 'docs/URITECT_EVALUATION_DEVICE_CHECKLIST.csv'
    with checklist.open(encoding='utf-8', newline='') as f:
        rows = list(csv.DictReader(f)); fields = list(rows[0])
    # Do not silently move observed old-build evidence onto a new build.
    assert all(r['status'] == 'NOT_RUN' and not r['actual_result'] for r in rows)
    for row in rows: row['build'] = version
    if not any(r['test_id'] == 'D16' for r in rows):
        rows.append(dict.fromkeys(fields, ''))
        rows[-1].update(build=version, test_id='D16', scenario='Mixed pad reaction times',
            expected_result='30/40/45/60 s pad restrictions and unknown/mismatched required-pad timing behave as documented', status='NOT_RUN')
    with checklist.open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fields); writer.writeheader(); writer.writerows(rows)
    decisions = ROOT / 'docs/URITECT_STATISTICAL_REVIEW_DECISIONS.csv'
    with decisions.open(encoding='utf-8', newline='') as f:
        rr = list(csv.DictReader(f)); ff = list(rr[0])
    assert all(r['decision'] == 'PENDING' for r in rr)
    for r in rr: r.update(build=version, apk_sha256=receipt['sha256'])
    with decisions.open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=ff); writer.writeheader(); writer.writerows(rr)
    print('Current build index and pending acceptance/review records bound to', version)


if __name__ == '__main__':
    main()
