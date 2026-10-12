"""Check completeness of thesis acceptance evidence; does not certify clinical validity."""
from __future__ import annotations
import argparse
import json
import math
from datetime import date
from pathlib import Path
from build_final_release_manifest import ROOT, OUTPUT, inventory, entry, dump
from verify_final_release_manifest import verify_entries, verify

PAD_ORDER = ['Leukocytes', 'Nitrite', 'Urobilinogen', 'Protein', 'pH', 'Blood', 'Specific Gravity', 'Ketone', 'Bilirubin', 'Glucose']

REQUIRED_CASES = {
    'STARTUP': 'Splash opens dashboard automatically; reduced motion and readable small-screen UI.',
    'OFFLINE_CAMERA': 'Airplane mode with Wi-Fi/mobile data disabled: camera analysis completes locally.',
    'OFFLINE_GALLERY': 'Airplane mode: selecting a locally stored photo completes analysis locally.',
    'CAMERA_DENIAL': 'Deny camera permission: explanation/recovery UI; no crash or stale image.',
    'CAMERA_RECOVERY': 'Grant camera in Android settings and resume: usable live preview.',
    'GALLERY_CANCEL_DENIAL': 'Cancel picker or deny access if offered: return safely; explain modern picker N/A.',
    'GALLERY_RECOVERY': 'Reopen picker and select local photo; previous cancellation does not block analysis.',
    'VALID_COOL_CAMERA': 'Properly timed supported strip under cool light: ten correct pad boxes or explicit retake.',
    'VALID_COOL_GALLERY': 'Cool-light local photo: assess pad overlay/classes against medtech reference.',
    'VALID_WARM_CAMERA': 'Properly timed supported strip under warm light: assess boxes/classes and retake.',
    'VALID_WARM_GALLERY': 'Warm-light local photo: assess boxes/classes and retake.',
    'VALID_DAYLIGHT_CAMERA': 'Properly timed supported strip in daylight: assess boxes/classes and retake.',
    'VALID_DAYLIGHT_GALLERY': 'Daylight local photo: assess boxes/classes and retake.',
    'CAMERA_GALLERY_COMPARISON': 'Controlled same-strip/light/angle camera and gallery comparison: record distinct file hashes, IFU times, overlays, categories and retake reasons.',
    'BLANK': 'No strip: explicit retake; no analyte or ordinary Bayesian result.',
    'BLURRY': 'Unresolvable pads: explicit retake; no reassuring result.',
    'DARK': 'Unreadable dark image: explicit retake.',
    'OVEREXPOSED': 'Unreadable clipped image: explicit retake.',
    'PARTIAL': 'Incomplete strip/pad stack: explicit retake.',
    'WRONG_STRIP': 'Unsupported product: quality checklist blocks interpretation; test automatic detector limitations.',
    'MULTIPLE_STRIPS': 'Multiple visible strips: explicit retake.',
    'LOW_CONFIDENCE': 'Supported located readings below 0.45 carry review notices; unsupported inputs reject. UTI/renal estimates require their own reliable pad sets, with symptom safety advice retained. Low pH/SG confidence alone must not block adequate independent UTI pads.',
    'RETAKE': 'New scan clears old photo/result and opens live camera; repeated retakes remain responsive.',
    'CAMERA_LIFECYCLE': 'Background/resume and gallery-return restore camera; rapid taps do not double-submit.',
    'FEMALE_ELIGIBILITY': 'Eligible symptomatic nonpregnant adult: separate female estimate with prior/factors/disclosure.',
    'MALE_ELIGIBILITY': 'Eligible symptomatic adult male: separate male estimate; no female factors.',
    'UTI_EXCLUSIONS': 'Age, pregnancy, catheter, abnormality, immunocompromise, male diabetes/STI: each blocks estimate.',
    'UTI_UNKNOWN': 'Unknown/unanswered quality/safety or unmatched/unreliable evidence: no ordinary estimate.',
    'SAFETY': 'Fever/flank, hydration failure, serious illness and renal safety override: consultation advice.',
    'RENAL': 'Exercise OBSERVE, REPEAT_CONFIRM, CONSULT, RETAKE and PROMPT_CONSULT using reviewed scenarios.',
    'HISTORY_SAVE_RESTART': 'Save and restart offline: image/results, original posterior and versions preserved.',
    'HISTORY_DELETE': 'Delete a designated test record: record/image removed; other records retained.',
    'LATENCY_CRASH': 'Record at least five measured scan durations, failures, crash/hang count and OS behavior.',
    'ACCESSIBILITY': 'Large text, back navigation and reduced motion usable without clipped controls.',
}

def acceptance_errors(data, manifest, root=ROOT):
    failures = []
    expected_hash = manifest['apk']['sha256']
    devices = data.get('devices', [])
    if len({d.get('model') for d in devices if d.get('model')}) < 2:
        failures.append('Two different physical Android phone models are required.')
    for device in devices:
        label = device.get('device_id', 'unknown device')
        for key in ['device_id', 'model', 'android_version', 'test_date', 'tester']:
            if not device.get(key):
                failures.append(label + ': missing ' + key)
        try:
            date.fromisoformat(device.get('test_date', ''))
        except (TypeError, ValueError):
            failures.append(label + ': invalid test date')
        if device.get('apk_sha256') != expected_hash:
            failures.append(label + ': tested APK checksum differs from frozen release.')
        cases = device.get('cases', [])
        if len({c.get('id') for c in cases}) != len(cases):
            failures.append(label + ': duplicate case IDs')
        by_id = {c.get('id'): c for c in cases}
        for case_id in REQUIRED_CASES:
            case = by_id.get(case_id, {})
            allowed_na = case_id == 'GALLERY_CANCEL_DENIAL'
            status = case.get('status')
            if status != 'PASS' and not (allowed_na and status == 'NOT_APPLICABLE'):
                failures.append(label + ': incomplete/failed ' + case_id)
            if not case.get('expected') or not case.get('actual'):
                failures.append(label + ': expected/actual required for ' + case_id)
            evidence = case.get('evidence', [])
            if not evidence:
                failures.append(label + ': screenshot/log evidence missing for ' + case_id)
            failures += verify_entries(root, evidence)
        times = device.get('scan_latency_seconds', [])
        if len(times) < 5 or any(not isinstance(v, (float, int)) or isinstance(v, bool)
                                 or not math.isfinite(v) or v < 0 for v in times):
            failures.append(label + ': five finite nonnegative scan durations required.')
        if device.get('crashes') != 0 or device.get('hangs') != 0:
            failures.append(label + ': unresolved crashes/hangs.')
    profile = data.get('physical_strip', {})
    for key in ['manufacturer', 'product', 'catalogue_number', 'lot', 'expiry', 'ifu_revision',
                'ifu_evidence', 'pad_order', 'categories', 'reading_times_seconds', 'reviewers']:
        if not profile.get(key):
            failures.append('Physical strip: missing ' + key)
    if profile.get('status') != 'confirmed_matches_frozen_app':
        failures.append('Physical strip/timing mappings are not confirmed.')
    if len(profile.get('pad_order', [])) != 10 or len(profile.get('reading_times_seconds', {})) != 10:
        failures.append('Ten-pad order and all ten IFU times are required.')
    if profile.get('pad_order') != PAD_ORDER:
        failures.append('Physical pad order differs from frozen model; needs reconciliation.')
    if set(profile.get('categories', {})) != set(PAD_ORDER):
        failures.append('All ten IFU category charts and units must be reconciled.')
    times = profile.get('reading_times_seconds', {})
    if any(not isinstance(times.get(pad), (int, float)) or isinstance(times.get(pad), bool)
           or not math.isfinite(times.get(pad)) or times.get(pad) <= 0 for pad in PAD_ORDER):
        failures.append('Every pad requires a finite positive manufacturer reading time.')
    for pad in PAD_ORDER:
        chart = profile.get('categories', {}).get(pad)
        if not isinstance(chart, dict) or not chart.get('units') or not chart.get('levels'):
            failures.append('IFU levels and units missing: ' + pad)
    if profile.get('timing_strategy_matches_app') is not True:
        failures.append('Per-pad reading times/capture strategy are not reconciled with the app.')
    if profile.get('reading_times_seconds', {}).get('Protein') != 60 or profile.get('reading_times_seconds', {}).get('Blood') != 60:
        failures.append('Physical protein/blood times conflict with frozen 60-second app checks.')
    if len(set(profile.get('reviewers', []))) < 2:
        failures.append('Two independent MedTech strip reviewers required.')
    failures += verify_entries(root, profile.get('ifu_evidence', []))
    reviews = data.get('reviews', {})
    for key in ['medtech_1', 'medtech_2', 'physician', 'statistician', 'usability_evaluation']:
        review = reviews.get(key, {})
        if review.get('status') != 'completed' or not review.get('reviewer') or not review.get('date'):
            failures.append('Human review incomplete: ' + key)
        if review.get('apk_sha256') != expected_hash:
            failures.append('Review must name the frozen build: ' + key)
        if not review.get('evidence'):
            failures.append('Signed review/analysis evidence missing: ' + key)
        failures += verify_entries(root, review.get('evidence', []))
    if data.get('clinical_calibration_status') != 'not_established':
        failures.append('Thesis acceptance cannot assert clinical calibration.')
    return failures

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', type=Path, default=ROOT / 'output/release/RELEASE_ACCEPTANCE_RECORD.json')
    parser.add_argument('--manifest', type=Path, default=OUTPUT)
    parser.add_argument('--seal-evidence', action='store_true', help='Seal completed evaluation checksums; refuses pending evidence')
    args = parser.parse_args()
    integrity = verify(args.manifest, current_inventory=inventory())
    if integrity:
        raise SystemExit('Release integrity failed before acceptance: ' + '\n'.join(integrity))
    data = json.loads(args.record.read_text(encoding='utf-8'))
    manifest = json.loads(args.manifest.read_text(encoding='utf-8'))
    failures = acceptance_errors(data, manifest)
    if failures:
        print('NOT FINAL: ' + str(len(failures)) + ' pending or failed evidence checks.')
        print('\n'.join(failures))
        raise SystemExit(1)
    if args.seal_evidence:
        target = ROOT / 'output/release/URITECT_THESIS_EVALUATION_MANIFEST.json'
        if target.exists():
            raise SystemExit('Evaluation manifest exists; preserve the frozen evidence rather than overwriting.')
        evidence = []
        for device in data['devices']:
            for case in device['cases']:
                evidence.extend(case['evidence'])
        evidence.extend(data['physical_strip']['ifu_evidence'])
        for review in data['reviews'].values():
            evidence.extend(review['evidence'])
        unique = {item['path']: item for item in evidence}
        dump(target, {'status': 'thesis_evaluation_evidence_complete',
                      'clinical_calibration_status': 'not_established',
                      'release_manifest': entry(args.manifest.resolve()),
                      'evaluation_record': entry(args.record.resolve()),
                      'evidence': sorted(unique.values(), key=lambda item: item['path'])})
        print('Evaluation evidence sealed:', target)
    print('Thesis acceptance evidence complete. This does not establish clinical calibration or deployment readiness.')

if __name__ == '__main__':
    main()
