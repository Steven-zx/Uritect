"""Seal the QA pilot candidate without replacing historical release evidence."""
import argparse
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
from build_final_release_manifest import inventory, sha256, entry, ROOT, CERTIFICATE

def log_text(folder,name):
    raw=(folder/name).read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--evidence-dir',type=Path,required=True)
    p.add_argument('--orientation-quarantine',action='store_true',help='Emergency release that deliberately withholds all classification')
    p.add_argument('--corrected-experimental-model',action='store_true',help='Explicitly authorized supervised experimental model replacement')
    args=p.parse_args();folder=args.evidence_dir.resolve()
    if args.orientation_quarantine and args.corrected_experimental_model:raise SystemExit('Conflicting profiles')
    snapshot=json.loads((folder/'SOURCE_SNAPSHOT.json').read_text())
    if inventory()!=snapshot['files']:raise SystemExit('Source drift after freeze; APK must be rebuilt from matching source.')
    if entry(ROOT/snapshot['archive']['path'])!=snapshot['archive']:raise SystemExit('Source archive changed.')
    tests=log_text(folder,'flutter_test.log')
    if 'All tests passed!' not in tests or 'No issues found!' not in log_text(folder,'flutter_analyze.log') or 'Built build' not in log_text(folder,'release_build.log'):
        raise SystemExit('Required Flutter checks did not pass.')
    checks=json.loads((folder/'AUTOMATED_CHECKS.json').read_text())
    if any(v['exit_code']!=0 for v in checks.values()):raise SystemExit('Automated check failure.')
    comparison=json.loads((folder/'runtime_comparison.json').read_text())
    if args.orientation_quarantine:
        regression=json.loads((folder/'runtime_regression.json').read_text())
        if any(c['after']['accepted'] for c in regression['cases']):raise SystemExit('Quarantined model must not accept any scan.')
        source=(ROOT/'uritect_app/lib/services/local_scan_analysis_service.dart').read_text()
        if 'MODEL_ORIENTATION_REVIEW_REQUIRED' not in source or 'reviewedPadDirections' not in source:raise SystemExit('Orientation quarantine gate missing.')
    elif args.corrected_experimental_model:
        authorization=json.loads((folder/'EXPERIMENTAL_MODEL_AUTHORIZATION.json').read_text())
        if authorization['user_response']!='Install corrected experimental classifier':raise SystemExit('Experimental authorization missing')
        regression=json.loads((folder/'runtime_regression.json').read_text())
        if any(c['after'].get('rejection_code')=='MODEL_ORIENTATION_REVIEW_REQUIRED' for c in regression['cases']):raise SystemExit('Corrected model remains suspended')
    elif comparison['lost'] or comparison['changed_previously_accepted']:raise SystemExit('Development regression needs review before sealing.')
    version=re.search(r'^version:\s*(\S+)\+(\d+)',(ROOT/'uritect_app/pubspec.yaml').read_text(),re.M)
    name,code=version.groups()
    apk=folder/f'Uritect_v{name}+{code}_release.apk'
    if apk.exists():raise SystemExit('Do not overwrite a previously sealed APK.')
    shutil.copy2(ROOT/'uritect_app/build/app/outputs/flutter-apk/app-release.apk',apk)
    env=dict(os.environ,JAVA_HOME=r'C:\Program Files\Android\Android Studio\jbr')
    sdk=Path(os.environ['LOCALAPPDATA'])/'Android/sdk/build-tools/36.0.0'
    def checked(command):return subprocess.check_output(command,env=env,text=True,stderr=subprocess.STDOUT)
    identity=checked([str(sdk/'aapt.exe'),'dump','badging',str(apk)])
    if f"package: name='ph.edu.wvsu.uritect' versionCode='{code}' versionName='{name}'" not in identity or 'application-debuggable' in identity:raise SystemExit('APK identity mismatch/debuggable.')
    signing=checked([str(sdk/'apksigner.bat'),'verify','--verbose','--print-certs',str(apk)])
    certificate=re.search(r'Signer #1 certificate SHA-256 digest:\s*(\w+)',signing).group(1).upper()
    if certificate!=CERTIFICATE:raise SystemExit('Unexpected release certificate.')
    permissions=checked([str(sdk/'aapt.exe'),'dump','permissions',str(apk)])
    if 'android.permission.INTERNET' in permissions:raise SystemExit('Unexpected network permission.')
    xml=checked([str(sdk/'aapt.exe'),'dump','xmltree',str(apk),'AndroidManifest.xml'])
    if not re.search(r'allowBackup[^\n]*=\(type 0x12\)0x0\s*$',xml,re.M) or 'dataExtractionRules' not in xml or 'fullBackupContent' not in xml:raise SystemExit('Protected-history backup policy missing.')
    with zipfile.ZipFile(apk) as package:
        for asset in (ROOT/'uritect_app/assets').rglob('*'):
            if not asset.is_file():continue
            key='assets/flutter_assets/'+asset.relative_to(ROOT/'uritect_app').as_posix()
            if key not in package.namelist():key=quote(key,safe='/')
            if hashlib.sha256(package.read(key)).hexdigest().upper()!=sha256(asset):raise SystemExit('APK asset mismatch: '+key)
    (folder/'APK_IDENTITY.txt').write_text(identity+'\n'+signing)
    (folder/'APK_PERMISSIONS.txt').write_text(permissions)
    (folder/'APK_SECURITY_MANIFEST.txt').write_text(xml)
    previous=json.loads((ROOT/'output/device_pilot/2026-10-07/1.4.2+15/SOURCE_SNAPSHOT.json').read_text())
    previous_model=next(i for i in previous['files'] if i['path']=='uritect_app/assets/production_semiquant_model.json')
    if args.corrected_experimental_model:
        current=json.loads((ROOT/previous_model['path']).read_text())
        candidate=json.loads((ROOT/'pipeline/output/orientation_audit_2026-10-11_v3/candidate_model.json').read_text())
        if current.get('experimental_research_only') is not True or current.get('clinical_validation_established') is not False or current.get('engineering_pad_order_verified') is not True:raise SystemExit('Experimental mapping/status metadata missing')
        if current['model_version']!='direction_verified_experimental_v1_20261011':raise SystemExit('Unexpected experimental model')
        for name, spec in candidate['analytes'].items():
            for key in ['train_vectors','train_labels','k','metric','weights','scaler','feature_set','feature_transform']:
                if spec[key]!=current['analytes'][name][key]:raise SystemExit('Experimental candidate mismatch: '+name+'/'+key)
    elif previous_model['sha256']!=sha256(ROOT/previous_model['path']):raise SystemExit('Unexpected production model change.')
    files=[folder/'SOURCE_SNAPSHOT.json',folder/'URITECT_SOURCE_SNAPSHOT.zip',
      folder/'AUTOMATED_CHECKS.json',folder/'runtime_comparison.json',folder/'runtime_regression.json',
      ROOT/'docs/URITECT_SECURITY_AND_INPUT_REVIEW_2026-10-10.md',
      ROOT/'pipeline/build_training_support_policy.py',ROOT/'pipeline/test_training_support_policy.py',Path(__file__).resolve()]
    files.extend(folder.glob('*.log'));files.extend(folder.glob('APK_*.txt'))
    report={'version':f'{name}+{code}','generated_at':datetime.now(timezone.utc).isoformat(),
      'status':('orientation_containment_classifier_suspended_pending_physical_pad_and_label_review' if args.orientation_quarantine else ('corrected_experimental_research_classifier_not_clinically_validated' if args.corrected_experimental_model else 'signed_QA_pilot_candidate_pending_native_security_and_device_acceptance')),
      'apk':entry(apk),'certificate_sha256':certificate,'source_snapshot_sha256':sha256(folder/'SOURCE_SNAPSHOT.json'),
      'source_archive_sha256':sha256(folder/'URITECT_SOURCE_SNAPSHOT.zip'),'checks':checks,
      'development_image_regression':comparison,'pipeline':('android_markerless_direction_guard_v5_quarantine_20261011' if args.orientation_quarantine else ('android_markerless_direction_guard_v6_experimental_20261011' if args.corrected_experimental_model else 'android_markerless_json_knn_v4_support_20261010')), 'classification_suspended':args.orientation_quarantine,
      'production_model_changed':args.corrected_experimental_model,'vote_confidence_threshold_changed':False,'bayesian_values_changed':False,
      'support_policy_status':'training-only engineering guard, not clinically validated',
      'native_security_device_tests':'Pending; mocked Flutter tests do not verify AndroidKeyStore on physical phones',
      'clinical_validation':'Not established','files':[entry(f) for f in sorted(set(files))]}
    (folder/'PILOT_BUILD.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report['apk'],indent=2))

if __name__=='__main__':main()
