"""Prepare pending records for the exact frozen release; never invent test results."""
from pathlib import Path
import json
from build_final_release_manifest import ROOT, OUTPUT, dump
from verify_release_acceptance import REQUIRED_CASES, PAD_ORDER

def main():
    record_path = ROOT / 'output/release/RELEASE_ACCEPTANCE_RECORD.json'
    if record_path.exists():
        raise SystemExit('Acceptance record exists. Preserve actual evidence; do not overwrite.')
    manifest = json.loads(OUTPUT.read_text(encoding='utf-8'))
    apk_hash = manifest['apk']['sha256']
    devices = []
    for label, model in [('phone_1', 'RMX3933'), ('phone_2', None)]:
        devices.append({
            'device_id': label, 'model': model, 'android_version': None,
            'test_date': None, 'tester': None, 'apk_sha256': apk_hash,
            'connection_status': 'deferred_by_user',
            'cases': [{'id': key, 'expected': text, 'actual': None, 'status': 'PENDING',
                       'input_sha256': [], 'evidence': [], 'issue_id': None}
                      for key, text in REQUIRED_CASES.items()],
            'scan_latency_seconds': [], 'crashes': None, 'hangs': None,
        })
    data = {
        'schema_version': 1, 'release': manifest['release'], 'status': 'pending_actual_evaluation',
        'clinical_calibration_status': 'not_established', 'devices': devices,
        'physical_strip': {
            'status': 'pending_user_and_medtech_confirmation',
            'manufacturer': None, 'product': None, 'catalogue_number': None,
            'lot': None, 'expiry': None, 'opening_date': None, 'storage_conditions': None,
            'ifu_revision': None, 'ifu_evidence': [], 'pad_order': [],
            'categories': {pad: None for pad in PAD_ORDER},
            'reading_times_seconds': {pad: None for pad in PAD_ORDER},
            'timing_strategy_matches_app': None, 'reviewers': [],
            'note': 'Ask user again next session, as requested 2026-10-06. App assumes protein/blood 60 seconds; all pad times require IFU reconciliation.',
        },
        'reviews': {key: {
            'status': 'pending', 'reviewer': None, 'credentials': None, 'date': None,
            'apk_sha256': apk_hash, 'decisions': [], 'evidence': [],
        } for key in ['medtech_1', 'medtech_2', 'physician', 'statistician', 'usability_evaluation']},
        'clinical_validation_note': 'Content review/usability is separate from culture-confirmed calibration and external performance validation.',
    }
    dump(record_path, data)
    print('Pending evaluation record:', record_path)

if __name__ == '__main__':
    main()
