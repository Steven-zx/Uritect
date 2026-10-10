"""Freeze app source before building; seal the exact signed candidate after checks."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from datetime import datetime, timezone
import zipfile
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'output/release/URITECT_FINAL_RELEASE_MANIFEST.json'
CERTIFICATE = '15D1138DCE077ADA624A140B3A145343D1A48305FD0847E9002869E488F19D39'

def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest().upper()

def entry(path):
    return {'path': path.relative_to(ROOT).as_posix(), 'bytes': path.stat().st_size,
            'sha256': sha256(path)}

def source_paths():
    app = ROOT / 'uritect_app'
    paths = set()
    for folder in ['lib', 'assets', 'test', 'tool', 'android/app/src', 'android/gradle/wrapper']:
        paths.update(p for p in (app / folder).rglob('*') if p.is_file() and 'failures' not in p.parts)
    for name in ['pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml',
                 'android/settings.gradle.kts', 'android/build.gradle.kts',
                 'android/app/build.gradle.kts', 'android/gradle.properties',
                 'android/gradlew', 'android/gradlew.bat']:
        path = app / name
        if path.is_file():
            paths.add(path)
    return sorted(paths)

def inventory():
    return [entry(p) for p in source_paths()]

def dump(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')

def freeze(folder):
    folder.mkdir(parents=True, exist_ok=True)
    before = inventory()
    snapshot, archive = folder / 'SOURCE_SNAPSHOT.json', folder / 'URITECT_SOURCE_SNAPSHOT.zip'
    if snapshot.exists() or archive.exists():
        raise SystemExit('Source freeze exists. Use a new version; do not overwrite a frozen candidate.')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as target:
        for item in before:
            target.write(ROOT / item['path'], item['path'])
    if inventory() != before:
        raise SystemExit('Source changed during snapshot creation.')
    dump(snapshot, {'frozen_at': datetime.now(timezone.utc).isoformat(),
                    'scope': 'App sources/assets/tests/tooling and locked build configuration; signing secrets excluded',
                    'files': before, 'archive': entry(archive)})
    print('Source frozen:', snapshot)

def checked(command, env=None):
    result = subprocess.run(command, capture_output=True, text=True, env=env)
    if result.returncode:
        raise SystemExit(result.stdout + result.stderr)
    return result.stdout + result.stderr

def seal(args):
    folder, apk = args.evidence_dir.resolve(), args.apk.resolve()
    snapshot = folder / 'SOURCE_SNAPSHOT.json'
    frozen = json.loads(snapshot.read_text(encoding='utf-8'))
    if inventory() != frozen['files']:
        raise SystemExit('App source differs from pre-build snapshot. Rebuild under a new version.')
    if entry(ROOT / frozen['archive']['path']) != frozen['archive']:
        raise SystemExit('Source archive changed.')
    version = re.search(r'^version:\s*(\S+)\+(\d+)', (ROOT / 'uritect_app/pubspec.yaml').read_text(), re.M)
    name, code = version.group(1), int(version.group(2))
    env = dict(os.environ, JAVA_HOME=str(args.jdk))
    tools = args.android_sdk / 'build-tools' / '36.0.0'
    badging = checked([str(tools / 'aapt.exe'), 'dump', 'badging', str(apk)], env)
    package = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging)
    if not package or package.groups() != ('ph.edu.wvsu.uritect', str(code), name):
        raise SystemExit('APK identity does not match frozen pubspec.')
    if 'application-debuggable' in badging:
        raise SystemExit('Debug APK cannot be sealed as a release.')
    signing = checked([str(tools / 'apksigner.bat'), 'verify', '--verbose', '--print-certs', str(apk)], env)
    certificate = re.search(r'Signer #1 certificate SHA-256 digest:\s*(\w+)', signing)
    if not certificate or certificate.group(1).upper() != CERTIFICATE:
        raise SystemExit('APK is not signed by the expected project release key.')
    (folder / 'APK_IDENTITY.txt').write_text(badging + '\n' + signing, encoding='utf-8')
    permissions = checked([str(tools / 'aapt.exe'), 'dump', 'permissions', str(apk)], env)
    if 'android.permission.INTERNET' in permissions:
        raise SystemExit('Offline candidate unexpectedly requests INTERNET permission.')
    (folder / 'APK_PERMISSIONS.txt').write_text(permissions, encoding='utf-8')
    with zipfile.ZipFile(apk) as packaged:
        for asset in (ROOT / 'uritect_app/assets').rglob('*'):
            if asset.is_file():
                packaged_name = 'assets/flutter_assets/' + asset.relative_to(ROOT / 'uritect_app').as_posix()
                # Flutter URI-encodes asset names (for example spaces become %20).
                if packaged_name not in packaged.namelist():
                    packaged_name = quote(packaged_name, safe='/')
                try:
                    actual = hashlib.sha256(packaged.read(packaged_name)).hexdigest().upper()
                except KeyError:
                    raise SystemExit('Frozen asset missing from APK: ' + packaged_name)
                if actual != sha256(asset):
                    raise SystemExit('APK asset differs from frozen source: ' + packaged_name)
    checks = json.loads((folder / 'AUTOMATED_CHECKS.json').read_text(encoding='utf-8-sig'))
    required = {'flutter_test', 'flutter_analyze', 'python_tests', 'model_export_parity', 'release_build'}
    if not required.issubset(checks) or any(item.get('exit_code') != 0 for item in checks.values()):
        raise SystemExit('All required automated checks must pass before sealing.')
    toolchain = json.loads((args.flutter_sdk / 'bin/cache/flutter.version.json').read_text(encoding='utf-8'))
    java = checked([str(args.jdk / 'bin/java.exe'), '-version'])
    files = {p for p in folder.rglob('*') if p.is_file()}
    files.add(apk)
    for doc in ['URITECT_RELEASE_ACCEPTANCE_2026-10-06.md', 'URITECT_PHYSICAL_STRIP_PROTOCOL.md',
                'URITECT_STATISTICAL_AND_EXPERT_REVIEW_PACKET.md', 'MANUSCRIPT_FINAL_REVISION_GUIDE.md',
                'FINAL_PROJECT_HANDOFF.md', 'ANDROID_RELEASE_SIGNING.md']:
        files.add(ROOT / 'docs' / doc)
    for script in ['build_final_release_manifest.py', 'verify_final_release_manifest.py',
                   'verify_release_acceptance.py', 'test_release_integrity.py', 'prepare_release_acceptance_record.py', 'bundle_offline_fonts.py']:
        files.add(ROOT / 'pipeline' / script)
    for evidence_name in ['runtime_before_after_regression.json', 'runtime_regression_summary.json', 'technical_review_summary.json']:
        files.add(ROOT / 'pipeline/output/abnormal_error_audit_2026-10-05' / evidence_name)
    data = {
        'schema_version': 2, 'release': 'URITECT ' + name + '+' + str(code),
        'status': 'signed_release_candidate_pending_device_and_human_evaluation',
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'android_application_id': 'ph.edu.wvsu.uritect',
        'android_version': {'name': name, 'code': code}, 'apk': entry(apk),
        'release_signing_certificate_sha256': certificate.group(1).upper(),
        'source_snapshot': entry(snapshot),
        'toolchain': {'flutter': toolchain, 'java': java, 'gradle': '8.14.3', 'agp': '8.11.1',
                      'kotlin': '2.1.0', 'android_api': 36,
                      'build_command': 'flutter build apk --release --no-pub'},
        'production_model_version': 'production_semiquant_knn_markerless_roi_topfix_v3_20260908',
        'pipeline_version': 'android_markerless_json_knn_v2_background_20261005',
        'bayesian_model_versions': {'female': 'uti_bayesian_female_v1_1_20260926',
                                   'male': 'uti_bayesian_male_v0_1_20261001'},
        'renal_rule_version': 'renal_followup_rules_v1.1_20260919',
        'clinical_validation': 'Not performed; no local culture-confirmed calibration',
        'evaluation_record': 'output/release/RELEASE_ACCEPTANCE_RECORD.json',
        'reproducibility_note': 'Pinned source/toolchain, not a claim of byte-for-byte identical rebuilds.',
        'files': [entry(p) for p in sorted(files)],
    }
    dump(OUTPUT, data)
    print('Sealed signed release candidate:', OUTPUT)
    print('APK SHA-256:', data['apk']['sha256'])

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--freeze-source', action='store_true')
    parser.add_argument('--evidence-dir', required=True, type=Path)
    parser.add_argument('--apk', type=Path)
    parser.add_argument('--flutter-sdk', type=Path)
    parser.add_argument('--android-sdk', type=Path)
    parser.add_argument('--jdk', type=Path)
    args = parser.parse_args()
    if args.freeze_source:
        freeze(args.evidence_dir.resolve())
    else:
        if not all([args.apk, args.flutter_sdk, args.android_sdk, args.jdk]):
            parser.error('Sealing requires --apk, --flutter-sdk, --android-sdk and --jdk')
        seal(args)

if __name__ == '__main__':
    main()
