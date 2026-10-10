"""Verify this pilot build without replacing the historical release manifest."""
import hashlib
import json
import os
import re
import shutil
import subprocess
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

root = Path.cwd()
folder = Path(__file__).resolve().parent
assert (root / 'uritect_app/pubspec.yaml').exists()
snapshot = json.loads((folder / 'SOURCE_SNAPSHOT.json').read_text())
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()
for item in snapshot['files']:
    assert digest(root / item['path']) == item['sha256'], item['path']
def log_text(name):
    raw = (folder / name).read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')
assert 'All tests passed!' in log_text('flutter_test.log')
assert 'No issues found!' in log_text('flutter_analyze.log')
assert 'Built build' in log_text('release_build.log')
comparison = json.loads((folder / 'runtime_comparison.json').read_text())
assert not comparison['lost'] and not comparison['changed_previously_accepted']
apk = folder / 'Uritect_v1.4.2+15_release.apk'
shutil.copy2(root / 'uritect_app/build/app/outputs/flutter-apk/app-release.apk', apk)
sdk = Path(os.environ['LOCALAPPDATA']) / 'Android/sdk/build-tools/36.0.0'
env = dict(os.environ, JAVA_HOME=r'C:\Program Files\Android\Android Studio\jbr')
def check(args):
    return subprocess.check_output(args, env=env, text=True, stderr=subprocess.STDOUT)
identity = check([str(sdk / 'aapt.exe'), 'dump', 'badging', str(apk)])
assert "package: name='ph.edu.wvsu.uritect' versionCode='15' versionName='1.4.2'" in identity
assert 'application-debuggable' not in identity
signing = check([str(sdk / 'apksigner.bat'), 'verify', '--verbose', '--print-certs', str(apk)])
cert = re.search(r'Signer #1 certificate SHA-256 digest:\s*(\w+)', signing).group(1).upper()
assert cert == '15D1138DCE077ADA624A140B3A145343D1A48305FD0847E9002869E488F19D39'
permissions = check([str(sdk / 'aapt.exe'), 'dump', 'permissions', str(apk)])
assert 'android.permission.INTERNET' not in permissions
with zipfile.ZipFile(apk) as packaged:
    for asset in (root / 'uritect_app/assets').rglob('*'):
        if asset.is_file():
            name = 'assets/flutter_assets/' + asset.relative_to(root / 'uritect_app').as_posix()
            if name not in packaged.namelist():
                name = quote(name, safe='/')
            assert hashlib.sha256(packaged.read(name)).hexdigest().upper() == digest(asset), str(asset)
(folder / 'APK_IDENTITY.txt').write_text(identity + '\n' + signing)
(folder / 'APK_PERMISSIONS.txt').write_text(permissions)
data = {
    'version': '1.4.2+15',
    'generated_at': datetime.now(timezone.utc).isoformat(),
    'status': 'signed_pilot_fix_pending_device_scan_confirmation_and_evaluation',
    'apk': {'path': apk.relative_to(root).as_posix(), 'bytes': apk.stat().st_size, 'sha256': digest(apk)},
    'certificate_sha256': cert,
    'source_snapshot_sha256': digest(folder / 'SOURCE_SNAPSHOT.json'),
    'source_archive_sha256': digest(folder / 'URITECT_SOURCE_SNAPSHOT.zip'),
    'checks': {'flutter_tests': 101, 'static_analysis': 'clean', 'previous_image_predictions_preserved': comparison},
    'pipeline': 'android_markerless_json_knn_v3_local_contrast_20261007',
    'model_changed': False,
    'confidence_threshold_changed': False,
    'bayesian_values_changed': False,
    'clinical_validation': 'Not established',
}
(folder / 'PILOT_BUILD.json').write_text(json.dumps(data, indent=2))
print(json.dumps(data['apk']))
