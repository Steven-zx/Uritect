"""Verify the current candidate's identity and refuse unsupported final acceptance."""
import argparse
import json
import re
from build_final_release_manifest import ROOT, inventory
from verify_final_release_manifest import verify_entries
from verify_release_acceptance import acceptance_errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--require-final', action='store_true')
    args = parser.parse_args()
    current = json.loads((ROOT / 'docs/CURRENT_EVALUATION_RELEASE.json').read_text())
    version = re.search(r'^version:\s*(\S+)', (ROOT / 'uritect_app/pubspec.yaml').read_text(), re.M)[1]
    errors = []
    if current['version'] != version: errors.append('Current release version differs from app')
    errors += verify_entries(ROOT, [current[k] for k in ['apk','build_receipt','source_snapshot','source_archive','model','strip_record']])
    snapshot = json.loads((ROOT / current['source_snapshot']['path']).read_text())
    if snapshot['files'] != inventory(): errors.append('Source drift after APK freeze')
    model = json.loads((ROOT / current['model']['path']).read_text())
    if current['model_version'] != model['model_version']: errors.append('Model version drift')
    if current['clinical_validation_established'] or model.get('clinical_validation_established'):
        errors.append('Clinical validation claim conflicts with absent outcome evidence')
    record = json.loads((ROOT / current['acceptance_record']).read_text())
    pending = acceptance_errors(record, {'apk':current['apk']}, ROOT)
    if record['release'] != version: errors.append('Acceptance record version drift')
    for key in ['manuscript','clinical_outcome_study']:
        if not record.get(key, {}).get('evidence'): pending.append(key + ': NOT VERIFIED - supporting evidence not located')
        pending += verify_entries(ROOT, record.get(key, {}).get('evidence', []))
    for key in ['medtech_3']:
        review = record['reviews'].get(key, {})
        if review.get('status') != 'completed' or not review.get('reviewer') or not review.get('date'):
            pending.append(key + ': planned content review pending')
        if review.get('apk_sha256') != current['apk']['sha256']:
            pending.append(key + ': review must identify the frozen APK')
        if not review.get('evidence'): pending.append(key + ': signed evidence missing')
        pending += verify_entries(ROOT, review.get('evidence', []))
    for key, review in record['reviews'].items():
        if not review.get('repository_commit_release_tag_or_version_reviewed'):
            pending.append(key + ': repository commit, release tag, or version reviewed is missing')
    result = {'version':version, 'artifact_integrity_passed':not errors,
              'engineering_errors':errors, 'external_acceptance_gaps':pending,
              'full_evidence_gaps_closed':not errors and not pending,
              'clinical_deployment_ready':False,
              'note':'Automated source/APK checks are separate from observed device, physical-strip, professional and outcome evidence.'}
    (ROOT / 'docs/URITECT_EVIDENCE_STATUS.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'version':version,'artifact_integrity_passed':not errors,
                      'external_acceptance_gaps':len(pending),'full_evidence_gaps_closed':result['full_evidence_gaps_closed']},indent=2))
    if errors or (args.require_final and pending): raise SystemExit(2)


if __name__ == '__main__':
    main()
