"""Prevent drift between the owner-confirmed strip record and runtime schedule."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class StripReadingScheduleTest(unittest.TestCase):
    def test_owner_record_and_runtime_schedule_match(self):
        record = json.loads((ROOT / 'docs/URITECT_PHYSICAL_STRIP_RECORD.json').read_text())
        contract = json.loads((ROOT / 'docs/URITECT_FINAL_PAD_ORDER.json').read_text())
        source = (ROOT / 'uritect_app/lib/models/strip_reading_schedule.dart').read_text()
        values = {code:int(seconds) for code,seconds in re.findall(r"'([^']+)':\s*(\d+)",source)}
        self.assertEqual(dict(zip(contract['codes'], [record['reading_times_seconds'][n] for n in contract['analytes']])), values)
        self.assertEqual({30,40,45,60},set(values.values()))

    def test_partial_record_does_not_become_independent_ifu_verification(self):
        record = json.loads((ROOT / 'docs/URITECT_PHYSICAL_STRIP_RECORD.json').read_text())
        self.assertIsNone(record['manufacturer'])
        self.assertFalse(record['vitamin_c_interference_protection_verified'])
        self.assertEqual([],record['signed_reviewers'])
        self.assertTrue(record['date_format_confirmed'])
        self.assertEqual('2026-05-12',record['manufacture_date'])
        self.assertEqual('2028-05-11',record['expiry_date'])


if __name__ == '__main__':
    unittest.main()
