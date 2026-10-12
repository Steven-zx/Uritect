"""Seal a source-matched signed evaluation APK without claiming clinical acceptance."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

from build_final_release_manifest import inventory, CERTIFICATE

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--evidence-dir', required=True, type=Path)
    parser.add_argument('--verification', type=Path)
    args = parser.parse_args()
    folder = args.evidence_dir.resolve()
    assert folder.is_relative_to(ROOT / 'output'), 'Evidence must stay in project output'
    version = re.search(r'^version:\s*(\S+)', (ROOT / 'uritect_app/pubspec.yaml').read_text(), re.M)[1]
    name, code = version.split('+')
    snapshot = json.loads((folder / 'SOURCE_SNAPSHOT.json').read_text())
    assert snapshot['files'] == inventory(), 'Source drift after freeze'
    archive = ROOT / snapshot['archive']['path']
    assert hashlib.sha256(archive.read_bytes()).hexdigest().upper() == snapshot['archive']['sha256'], 'Source archive drift'
    source = ROOT / 'uritect_app/build/app/outputs/flutter-apk/app-release.apk'
    target = folder / f'Uritect_v{version}_release.apk'
    assert not target.exists(), 'Frozen APK must not be overwritten'
    sdk_tools = Path(os.environ['LOCALAPPDATA']) / 'Android/sdk/build-tools/36.0.0'
    env = dict(os.environ, JAVA_HOME=r'C:\Program Files\Android\Android Studio\jbr')
    def run(tool, *arguments):
        process = subprocess.run([str(sdk_tools / tool), *arguments], capture_output=True, text=True, env=env, check=True)
        return process.stdout + process.stderr
    identity = run('aapt.exe', 'dump', 'badging', str(source))
    assert f"package: name='ph.edu.wvsu.uritect' versionCode='{code}' versionName='{name}'" in identity
    assert 'application-debuggable' not in identity
    signing = run('apksigner.bat', 'verify', '--verbose', '--print-certs', str(source))
    certificate = re.search(r'Signer #1 certificate SHA-256 digest:\s*(\w+)', signing)[1].upper()
    assert certificate == CERTIFICATE
    permissions = run('aapt.exe', 'dump', 'permissions', str(source))
    assert 'android.permission.INTERNET' not in permissions
    assets = {}
    with zipfile.ZipFile(source) as apk:
        for asset in ('production_semiquant_model.json', 'training_support_policy.json'):
            contents = (ROOT / 'uritect_app/assets' / asset).read_bytes()
            assert apk.read('assets/flutter_assets/assets/' + asset) == contents
            assets[asset] = hashlib.sha256(contents).hexdigest().upper()
    shutil.copy2(source, target)
    checksum = hashlib.sha256(target.read_bytes()).hexdigest().upper()
    (folder / 'APK_IDENTITY.txt').write_text(identity + '\n' + signing, encoding='utf-8')
    (folder / 'APK_PERMISSIONS.txt').write_text(permissions, encoding='utf-8')
    (folder / 'SHA256SUMS.txt').write_text(f'{checksum}  {target.name}\n', encoding='utf-8')
    verification = json.loads((args.verification or ROOT / 'pipeline/output/ph_sg_error_audit_2026-10-11/VERIFICATION.json').read_text())
    receipt = {
        'version': version, 'apk': target.relative_to(ROOT).as_posix(),
        'bytes': target.stat().st_size, 'sha256': checksum,
        'certificate_sha256': certificate, 'source_matches_archive': True,
        'embedded_assets': assets, 'offline_permissions_verified': True,
        'verification': verification,
        'purpose': 'Frozen developer-evaluation research prototype; existing experimental classifier retained after focused audit',
        'clinical_validation_established': False, 'phone_installation': 'not performed for this build',
        'pending': ['Exact APK manual device evaluation', 'Physical-strip lot/expiry/IFU documentation',
                    'Recorded professional review and usability results', 'Independent outcome validation before clinical accuracy/calibration claims'],
    }
    (folder / 'EVALUATION_BUILD.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: receipt[k] for k in ('version', 'apk', 'sha256', 'source_matches_archive')}, indent=2))


if __name__ == '__main__':
    main()
