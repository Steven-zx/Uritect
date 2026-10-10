import copy
import json
from pathlib import Path
import tempfile
import unittest
from build_final_release_manifest import sha256
from verify_final_release_manifest import verify_entries, safe_path, verify
from verify_release_acceptance import acceptance_errors, REQUIRED_CASES, PAD_ORDER

class ReleaseIntegrityTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'evidence.txt').write_text('real evidence fixture')
        self.evidence = {'path': 'evidence.txt', 'bytes': (self.root / 'evidence.txt').stat().st_size,
                         'sha256': sha256(self.root / 'evidence.txt')}
        self.manifest = {'apk': {'sha256': 'A' * 64}}

    def valid_record(self):
        case_list = [{'id': key, 'status': 'PASS', 'expected': text, 'actual': 'Observed in fixture',
                      'evidence': [self.evidence]} for key, text in REQUIRED_CASES.items()]
        device = {'device_id': 'one', 'model': 'RMX fixture', 'android_version': '16',
                  'test_date': '2026-10-06', 'tester': 'test fixture',
                  'apk_sha256': 'A' * 64, 'cases': case_list,
                  'scan_latency_seconds': [1, 2, 1, 2, 1], 'crashes': 0, 'hangs': 0}
        second = copy.deepcopy(device)
        second.update(device_id='two', model='Second fixture')
        reviews = {key: {'status': 'completed', 'reviewer': 'fixture ' + key, 'date': '2026-10-06',
                         'apk_sha256': 'A' * 64, 'evidence': [self.evidence]}
                   for key in ['medtech_1', 'medtech_2', 'physician', 'statistician', 'usability_evaluation']}
        return {'devices': [device, second], 'reviews': reviews,
                'clinical_calibration_status': 'not_established',
                'physical_strip': {'manufacturer': 'fixture', 'product': 'fixture', 'catalogue_number': 'fixture',
                                   'lot': 'fixture', 'expiry': '2027-01-01', 'ifu_revision': 'fixture',
                                   'ifu_evidence': [self.evidence], 'pad_order': PAD_ORDER,
                                   'categories': {pad: {'units': 'fixture', 'levels': ['fixture']} for pad in PAD_ORDER},
                                   'reading_times_seconds': {pad: 60 for pad in PAD_ORDER},
                                   'reviewers': ['fixture 1', 'fixture 2'],
                                   'timing_strategy_matches_app': True,
                                   'status': 'confirmed_matches_frozen_app'}}

    def test_complete_record_is_accepted_as_evidence_only(self):
        self.assertEqual([], acceptance_errors(self.valid_record(), self.manifest, self.root))

    def test_ifu_timing_conflict_blocks_completion(self):
        record = self.valid_record()
        record['physical_strip']['reading_times_seconds']['Protein'] = 120
        self.assertTrue(any('times conflict' in e for e in acceptance_errors(record, self.manifest, self.root)))

    def test_confirmed_label_does_not_hide_missing_ifu_data(self):
        record = self.valid_record()
        record['physical_strip']['reading_times_seconds']['Leukocytes'] = None
        record['physical_strip']['categories']['Glucose'] = None
        errors = acceptance_errors(record, self.manifest, self.root)
        self.assertTrue(any('Every pad' in e for e in errors))
        self.assertTrue(any('Glucose' in e for e in errors))

    def test_content_tampering_detected_even_same_size(self):
        (self.root / 'evidence.txt').write_text('fake evidence fixture')
        self.assertTrue(verify_entries(self.root, [self.evidence]))

    def test_external_path_rejected(self):
        with self.assertRaises(ValueError):
            safe_path(self.root, '../outside')
        self.assertTrue(verify_entries(self.root, [dict(self.evidence, path='../outside')]))

    def test_added_source_file_is_drift(self):
        snapshot = self.root / 'snapshot.json'
        snapshot.write_text(json.dumps({'files': [self.evidence], 'archive': self.evidence}))
        snapshot_entry = {'path': 'snapshot.json', 'bytes': snapshot.stat().st_size, 'sha256': sha256(snapshot)}
        manifest = self.root / 'manifest.json'
        manifest.write_text(json.dumps({'schema_version': 2, 'files': [self.evidence],
                                        'apk': self.evidence, 'source_snapshot': snapshot_entry}))
        self.assertEqual([], verify(manifest, self.root, [self.evidence]))
        self.assertTrue(any('Source drift' in error for error in verify(manifest, self.root, [])))

    def test_legacy_release_manifest_not_current(self):
        path = self.root / 'manifest.json'
        path.write_text(json.dumps({'files': []}))
        self.assertTrue(verify(path, self.root))

    def test_pending_records_cannot_be_marked_final(self):
        errors = acceptance_errors({'devices': [], 'reviews': {}}, self.manifest, self.root)
        self.assertTrue(any('Two different' in item for item in errors))
        self.assertTrue(any('Human review' in item for item in errors))

    def test_pending_null_date_is_reported_without_crashing(self):
        record = self.valid_record()
        record['devices'][0]['test_date'] = None
        self.assertTrue(any('invalid test date' in e for e in acceptance_errors(record, self.manifest, self.root)))

    def test_other_apk_evidence_rejected(self):
        record = self.valid_record()
        record['devices'][0]['apk_sha256'] = 'B' * 64
        self.assertTrue(any('checksum differs' in item for item in acceptance_errors(record, self.manifest, self.root)))

    def test_duplicate_model_is_not_two_phone_models(self):
        record = self.valid_record()
        record['devices'][1]['model'] = record['devices'][0]['model']
        self.assertTrue(any('Two different' in item for item in acceptance_errors(record, self.manifest, self.root)))

    def test_missing_and_failed_case_rejected(self):
        record = self.valid_record()
        record['devices'][0]['cases'] = record['devices'][0]['cases'][1:]
        record['devices'][1]['cases'][0]['status'] = 'FAIL'
        errors = acceptance_errors(record, self.manifest, self.root)
        self.assertTrue(any('incomplete/failed STARTUP' in item for item in errors))

    def test_same_apk_review_and_evidence_required(self):
        record = self.valid_record()
        record['reviews']['statistician']['apk_sha256'] = 'B' * 64
        record['reviews']['physician']['evidence'] = []
        errors = acceptance_errors(record, self.manifest, self.root)
        self.assertTrue(any('statistician' in item for item in errors))
        self.assertTrue(any('physician' in item for item in errors))

    def test_usability_and_content_review_cannot_claim_calibration(self):
        record = self.valid_record()
        record['clinical_calibration_status'] = 'validated'
        self.assertTrue(any('cannot assert clinical calibration' in item
                            for item in acceptance_errors(record, self.manifest, self.root)))

if __name__ == '__main__':
    unittest.main()
