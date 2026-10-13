"""Revalidate the retained photographs using the current, unchanged Dart detector."""
import json
from pathlib import Path
from audit_legacy_dataset import ROOT, file_digest, dump
from prepare_legacy_runtime_audit import WRAPPER

OLD = ROOT / 'pipeline/output/legacy_dataset_audit_2026-10-13'
OUT = ROOT / 'pipeline/output/knn_runtime_metric_2026-10-13'


def main():
    OUT.mkdir(exist_ok=True)
    target = OUT / 'runtime_detector'
    target.mkdir(exist_ok=True)
    records = json.loads((OLD / 'FINAL_PHOTO_AUDIT.json').read_text())
    accepted = {r['image_sha256']: r for r in records if r['status'] == 'accepted_training'}
    items = {}
    for name in ['RUNTIME_MANIFEST.json', 'RUNTIME_CONTEXT_CROP_MANIFEST.json']:
        for item in json.loads((OLD / name).read_text())['photos']:
            key = item['image_sha256']
            item = dict(item, input_kind=item.get('input_kind', 'original_photo'),
                        input_sha256=item.get('input_sha256', key))
            if key in accepted and item['input_kind'] == accepted[key]['runtime_input_kind']:
                item = dict(item, output_directory=str(target.resolve()))
                assert file_digest(Path(item['image_path'])) == item['input_sha256']
                items[key] = item
    assert len(items) == len(accepted)
    source = ROOT / 'uritect_app/lib/services/local_scan_analysis_service.dart'
    text = source.read_text(encoding='utf-8').replace("import '../models/", "import 'package:uritect_app/models/")
    for name in ['training_support_policy', 'runtime_pad_features', 'photo_quality_check', 'pad_presence_check']:
        text = text.replace(f"import '{name}.dart';", f"import 'package:uritect_app/services/{name}.dart';")
    text = "import 'package:flutter_test/flutter_test.dart';\nimport 'package:crypto/crypto.dart' as crypto;\n" + text + WRAPPER
    harness = ROOT / 'tmp/runtime_metric_detector_test.dart'
    harness.parent.mkdir(exist_ok=True)
    harness.write_text(text, encoding='utf-8')
    dump(OUT / 'PRIVATE_RUNTIME_MANIFEST.json', dict(photos=list(items.values())))
    dump(OUT / 'ANALYSIS_PLAN.json', {
        'date': '2026-10-13', 'retained_images_to_recheck': len(items),
        'detector_sha256': file_digest(source), 'harness_sha256': file_digest(harness),
        'pad_presence_guard_sha256': file_digest(ROOT / 'uritect_app/lib/services/pad_presence_check.dart'),
        'installed_classifier_sha256': file_digest(ROOT / 'uritect_app/assets/production_semiquant_model.json'),
        'design': 'Current-detector revalidation followed by nested grouped development-only comparison of runtime feature recipes and kNN metric settings. No inspected confirmation events enter tuning.',
        'selection': 'Inner folds prioritize macro F1 and class sensitivity, with accuracy, specificity and kappa checked for Pareto non-regression. Outer fold results are exploratory and cannot be reused as an untouched final test.',
        'data_rules': 'Original labels and binary data unchanged. No artificial rare specimens. Duplicate exports excluded. Conservative participant-token grouping and confirmation exclusions retained.',
        'promotion': 'All five metrics must not decrease versus the paired baseline; macro F1 must improve. Supported abnormal-rule sensitivity/specificity, whole-ten accuracy and retake coverage must not regress. No confidence threshold reduction. Runtime parity and model-bound distance support required before deployment.',
        'clinical_validation_established': False,
    })
    print('Prepared', len(items), 'retained photographs for current-detector revalidation.')


if __name__ == '__main__':
    main()
