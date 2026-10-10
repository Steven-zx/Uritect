"""Create a separate sanitized evaluator checkout from the frozen app snapshot."""
import ast
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'developer_evaluation/URITECT'
BUILD = ROOT / 'output/device_pilot/2026-10-11/1.5.11+28'


def main():
    assert not DEST.exists(), 'Preserve existing evaluator checkout'
    DEST.mkdir(parents=True)
    snapshot = json.loads((BUILD / 'SOURCE_SNAPSHOT.json').read_text())
    with zipfile.ZipFile(BUILD / 'URITECT_SOURCE_SNAPSHOT.zip') as archive:
        for item in snapshot['files']:
            name = item['path']
            target = DEST / name
            assert target.resolve().is_relative_to(DEST.resolve())
            data = archive.read(name)
            assert hashlib.sha256(data).hexdigest().upper() == item['sha256']
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    docs = ['URITECT_FINAL_PAD_ORDER.json', 'URITECT_FINAL_PAD_ORIENTATION.md',
            'URITECT_PHYSICAL_STRIP_PROTOCOL.md', 'URITECT_STATISTICAL_AND_EXPERT_REVIEW_PACKET.md',
            'URITECT_SECURITY_AND_INPUT_REVIEW_2026-10-10.md',
            'URITECT_EVALUATION_DEVICE_CHECKLIST.csv']
    for name in docs:
        (DEST / 'docs').mkdir(exist_ok=True)
        shutil.copy2(ROOT / 'docs' / name, DEST / 'docs' / name)
    # Minimal executable pipeline dependency closure, rather than historical scripts.
    seeds = ['runtime_pad_features', 'focused_pad_geometry', 'markerless_strip',
             'vision_pipeline', 'semiquant_schema', 'specimen_grouping',
             'test_focused_pad_audit', 'test_final_pad_order']
    pending, included = list(seeds), set()
    while pending:
        module = pending.pop()
        source = ROOT / 'pipeline' / (module + '.py')
        if module in included or not source.exists():
            continue
        included.add(module)
        tree = ast.parse(source.read_text(encoding='utf-8-sig'))
        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom) and node.module:
                pending.append(node.module.split('.')[0])
            elif isinstance(node, ast.Import):
                pending.extend(n.name.split('.')[0] for n in node.names)
        target = DEST / 'pipeline' / source.name
        target.parent.mkdir(exist_ok=True)
        shutil.copy2(source, target)
    (DEST / 'pipeline/requirements.txt').write_text('numpy==2.4.3\nopencv-python==4.13.0.92\n', encoding='utf-8')
    evidence = DEST / 'docs/build'
    evidence.mkdir()
    for name in ('SOURCE_SNAPSHOT.json', 'EVALUATION_BUILD.json', 'APK_IDENTITY.txt', 'APK_PERMISSIONS.txt', 'SHA256SUMS.txt'):
        shutil.copy2(BUILD / name, evidence / name)
    metrics = DEST / 'docs/performance'
    metrics.mkdir()
    for source, target in [
        ('pipeline/output/knn_improvement_2026-10-11/REPORT.md', 'GROUPED_EXPERIMENT.md'),
        ('pipeline/output/ph_sg_error_audit_2026-10-11/REPORT.md', 'PH_SG_EXPERIMENT.md'),
        ('pipeline/output/ph_sg_error_audit_2026-10-11/PYTHON_ENVIRONMENT.json', 'PYTHON_ENVIRONMENT.json'),
    ]:
        shutil.copy2(ROOT / source, metrics / target)
    (DEST / '.gitignore').write_text('''__pycache__/
*.py[cod]
.venv/
**/.dart_tool/
**/.dart-tool/
uritect_app/**/build/
**/.gradle/
**/.kotlin/
**/.idea/
**/.flutter-plugins*
**/local.properties
**/key.properties
*.jks
*.keystore
*.apk
*.zip
*.iml
pipeline/dataset/
pipeline/output/
.DS_Store
''', encoding='utf-8')
    (DEST / 'README.md').write_text('''# URITECT — developer evaluation

Frozen Android research prototype **1.5.11+28**, package `ph.edu.wvsu.uritect`.
Start with [the evaluation guide](docs/EVALUATION_GUIDE.md).

- `uritect_app/`: exact frozen app source, locked dependencies, model assets and tests.
- `pipeline/`: selected image/feature/schema helpers, dependency closure and focused tests.
- `docs/`: evaluation protocol, security scope, pad-order contract and build/performance evidence.

From `uritect_app`: `flutter pub get`, `flutter analyze`, `flutter test`.
For local installation: `flutter build apk --debug`.
Release signing keys are owner-managed and excluded. The signed evaluation APK is distributed separately with [its checksum](docs/build/SHA256SUMS.txt).

This repository excludes private research datasets, patient history, raw specimen photos, caches and historical binaries. Small pre-existing de-identified app regression fixtures are included for automated testing. Dataset-dependent experiments require separately authorized data access.

The classifier and Bayesian component are experimental; clinical validation is not established. No license is granted by this evaluation package; agree distribution and contribution terms with the project owner.
''', encoding='utf-8')
    (DEST / 'docs/EVALUATION_GUIDE.md').write_text('''# Evaluation guide

## Current implementation

Offline camera/gallery analysis, orientation-aware ten-pad localization, per-analyte k-NN, confidence/distance checks, actual-photo progressive sampling overlays, safety checklist, provisional Bayesian UTI estimates, renal follow-up and protected editable history.

Physical order from tip toward handle: **LEU → NIT → URO → PRO → pH → BLD → SG → KET → BIL → GLU**. See [the contract](URITECT_FINAL_PAD_ORIENTATION.md).

The app model remains `direction_verified_experimental_v1_20261011`. No pH/SG experiment candidate was deployed. [Grouped results](performance/GROUPED_EXPERIMENT.md) and [focused experiments](performance/PH_SG_EXPERIMENT.md) are exploratory category-classification evidence, not disease-detection accuracy. Their references to raw review sheets and full historical experiment outputs refer to the owner's research workspace and are intentionally not included here.

## Environment and checks

Observed environment: Flutter 3.41.9, Dart 3.11.5, Gradle 8.14.3, Android build-tools 36.0.0 and Android Studio bundled JDK. Gradle wrapper and pubspec.lock are included. Use your own Android SDK configuration; no owner's local SDK paths or signing credentials are supplied.

The full owner checkout passed **143 Flutter tests, 50 Python tests and clean static analysis**. This smaller repository includes a subset of pipeline tests; do not claim it independently ran all 50. [The receipt](build/EVALUATION_BUILD.json) records observed checks, APK identity and hashes. [The source inventory](build/SOURCE_SNAPSHOT.json) identifies frozen app files. Artifact paths in those receipts are provenance paths in the owner's original workspace.

For selected Python checks, install `pipeline/requirements.txt`, then run `python -m unittest discover -s pipeline -p 'test_*.py'`. The app runs locally without the Python pipeline or a server. Python package versions used for the audit are [recorded here](performance/PYTHON_ENVIRONMENT.json).

## Review priorities

Inspect `lib/services/local_scan_analysis_service.dart` for geometry/orientation/inference; `runtime_pad_features.dart` for shared color math; `scan_model.dart` for reliability; `screening_fusion.dart` and `renal_followup.dart` for required-pad interpretation gates; `scan_history_service.dart` and native `HistorySecurity.kt` for persistence/security; and the analysis/results pages for lifecycle/navigation.

Complete [the device checklist](URITECT_EVALUATION_DEVICE_CHECKLIST.csv) with actual observations on two phones. Review [security guarantees and limits](URITECT_SECURITY_AND_INPUT_REVIEW_2026-10-10.md). Test in-place updates without clearing data. Geometry overlays do not guarantee correct readings; k-NN confidence is not a calibrated probability.

## Outstanding external evidence

Exact-build manual device acceptance, [physical-strip manufacturer/lot/expiry/IFU details](URITECT_PHYSICAL_STRIP_PROTOCOL.md), and [recorded expert/usability review](URITECT_STATISTICAL_AND_EXPERT_REVIEW_PACKET.md) remain pending. Pad orientation is owner-reported MedTech verified. Clinical calibration and local culture-confirmed outcome validation are not established. pH majority bias, SG class overlap, small rare-class support and inspected evaluation sets remain limitations. Preserve these disclosures in evaluation reports.

Report issues with device/Android version, steps, expected/actual behavior, build version and de-identified screenshots. Never upload participant identifiers, specimen photographs or signing credentials to a public issue.
''', encoding='utf-8')
    files = [p for p in DEST.rglob('*') if p.is_file()]
    prohibited = {'key.properties', 'local.properties'}
    assert not any(p.name in prohibited or p.suffix.lower() in {'.apk', '.zip', '.jks', '.keystore'} for p in files)
    assert max(p.stat().st_size for p in files) < 100_000_000
    manifest = {'version': '1.5.11+28', 'frozen_app_files_verified': len(snapshot['files']),
                'pipeline_modules': sorted(included), 'raw_research_data_included': False,
                'signing_secrets_included': False,
                'files': [{'path':p.relative_to(DEST).as_posix(), 'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(files)]}
    (DEST / 'EVALUATION_PACKAGE.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    print(f'Created {DEST}: {len(files)} files, frozen app inventory verified.')


if __name__ == '__main__':
    main()
