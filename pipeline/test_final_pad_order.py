"""Prevent drift from the project's final physical tip-to-handle contract."""
import ast
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = json.loads((ROOT / 'docs/URITECT_FINAL_PAD_ORDER.json').read_text())

def dart_list(path, declaration):
    source = (ROOT / path).read_text()
    block = re.search(re.escape(declaration) + r'\s*=\s*\[(.*?)\];', source, re.S)
    if block is None:
        raise AssertionError('Pad-order declaration missing: ' + path)
    return re.findall(r"'([^']+)'", block.group(1))

class FinalPadOrderTest(unittest.TestCase):
    def test_app_analyzer_and_camera_guide_share_final_order(self):
        self.assertEqual(dart_list('uritect_app/lib/services/local_scan_analysis_service.dart', 'const List<String> _analyteOrder'), CONTRACT['analytes'])
        self.assertEqual(dart_list('uritect_app/lib/widgets/ten_pad_alignment_guide.dart', 'static const labels'), CONTRACT['codes'])

    def test_python_geometry_and_category_schema_share_final_order(self):
        for file, variable in [('pipeline/vision_pipeline.py', 'ANALYTE_ORDER'), ('pipeline/semiquant_schema.py', 'ANALYTE_LEVEL_SCHEMA')]:
            tree = ast.parse((ROOT / file).read_text())
            node = next(n for n in tree.body if isinstance(n, ast.AnnAssign) and n.target.id == variable)
            value = ast.literal_eval(node.value)
            self.assertEqual(list(value), CONTRACT['analytes'])

    def test_bundled_model_uses_the_same_physical_contract(self):
        model = json.loads((ROOT / 'uritect_app/assets/production_semiquant_model.json').read_text())
        self.assertEqual(model['analyte_order'], CONTRACT['analytes'])
        self.assertEqual(model['pad_order_verification']['tip_to_handle'], CONTRACT['codes'])
        self.assertEqual(set(model['analytes']), set(CONTRACT['analytes']))
        self.assertTrue(model['engineering_pad_order_verified'])

if __name__ == '__main__':
    unittest.main()
