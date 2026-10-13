"""Write aggregate findings without publishing original patient/photo metadata."""
import json
import csv
from audit_legacy_dataset import DEFAULT_OUT


def percent(value):
    return 'Undefined' if value is None else f'{100*value:.2f}%'


def run(out=DEFAULT_OUT):
    summary=json.loads((out/'FINAL_SUMMARY.json').read_text())
    comparison=json.loads((out/'DEVELOPMENT_COMPARISON.json').read_text())
    integrity=json.loads((out/'SOURCE_INTEGRITY.json').read_text())
    plan=comparison['plan']
    lines=['# Legacy dataset cleaning and development comparison', '',
      'Original images, binary values and semiquantitative reference categories are preserved. '
      'Printed color charts, unsupported converted references and conflicting labels do not become specimen training data.', '',
      f'- {summary["unique_photos"]:,} unique images reviewed, including {summary["unique_archive_photos"]:,} archive photos and {summary["additional_unpacked_photos"]:,} additional unpacked originals.',
      f'- {summary["archive_occurrences"]:,} archive occurrences; {summary["byte_duplicate_export_occurrences"]:,} repeated export occurrences consolidated.',
      f'- {summary["training_photos"]:,} photographs qualify for the versioned training pool, with {summary["training_reference_groups"]:,} within-batch reference groups. These are not established independent-patient counts.',
      f'- {summary["training_photos_requiring_archive_crop"]:,} retained photos require archival context crops. This does not demonstrate that the unchanged app accepts their uncropped originals.',
      f'- Source integrity: {integrity["checked_files"]} protected files checked; all unchanged: {integrity["all_unchanged"]}.', '',
      '## Photo dispositions', '', '| Status | Photos |', '|---|---:|']
    lines += [f'| {status} | {count} |' for status,count in summary['statuses'].items()]
    lines += ['', '## Paired exploratory development comparison', '',
      plan['design'], '',
      f'The paired target comprises {plan["paired_audited_target_events"]} freshly audited development photos; '
      f'{plan["target_events_excluded_by_audit"]} original development photos did not enter this paired target. '
      f'The {plan["baseline_confirmation_events_not_evaluated"]}-photo historical confirmation subset was not evaluated. '
      'The results below are not directly comparable with older 79.92% or 82.52% figures from different photos/splits.', '',
      'Each cell shows baseline → candidate accuracy. The two candidates use cleaned current-only data and cleaned current-plus-legacy data. '
      'Selection also considers macro F1, macro sensitivity/specificity, supported downstream-threshold errors and paired group uncertainty; accuracy alone cannot qualify a candidate.', '',
      '| Analyte | Cleaned current-only | Cleaned + legacy | Qualified recipe |', '|---|---:|---:|---|']
    for a,r in comparison['per_analyte'].items():
        old=percent(r['baseline']['accuracy'])
        lines.append(f'| {a} | {old} → {percent(r["candidates"]["cleaned_current_only"]["metrics"]["accuracy"])} | '
                     f'{old} → {percent(r["candidates"]["cleaned_plus_legacy"]["metrics"]["accuracy"])} | {r["selected"]} |')
    metric_rows=[]
    for arm in ['baseline','cleaned_current_only','cleaned_plus_legacy']:
        lines += ['', f'### Five metrics: {arm}', '',
          '| Analyte | Accuracy | Macro F1 | Macro sensitivity | Macro specificity | Cohen\'s kappa |',
          '|---|---:|---:|---:|---:|---:|']
        for a,r in comparison['per_analyte'].items():
            m=r['baseline'] if arm=='baseline' else r['candidates'][arm]['metrics']
            keys=['accuracy','macro_f1_supported_reference_classes','macro_sensitivity','macro_specificity']
            kappa=m['cohens_kappa']
            lines.append('| '+a+' | '+' | '.join(percent(m[k]) for k in keys)+' | '+('Undefined' if kappa is None else f'{kappa:.4f}')+' |')
            metric_rows.append(dict(analyte=a,arm=arm,n=m['n'],**{k:m[k] for k in keys},cohens_kappa=kappa,
                scope='paired_3_fold_grouped_development_exploratory'))
    with (out/'FIVE_METRICS.csv').open('w',encoding='utf-8',newline='') as stream:
        writer=csv.DictWriter(stream,fieldnames=list(metric_rows[0]));writer.writeheader();writer.writerows(metric_rows)
    lines += ['', '| Joint measure | Baseline | Qualified combination |', '|---|---:|---:|']
    for key in ['individual_accuracy','all_ten_accuracy','feature_stage_retake_rate','feature_stage_accepted_all_ten_accuracy']:
        lines.append(f'| {key} | {percent(comparison["baseline_whole"][key])} | {percent(comparison["selected_whole"][key])} |')
    lines += ['', '**Promotion decision:** '+ ('Eligible for separate Dart parity and release verification; not yet installed or clinically validated.'
      if comparison['joint_engineering_screen']['passed'] else 'Keep the current app model. The expanded pool did not qualify for promotion.'), '',
      '; '.join(comparison['joint_engineering_screen']['reasons']) or 'The predeclared engineering comparison passed.', '',
      '## Limits and retained artifacts', '',
      '- Every original remains intact. Exclusion means exclusion from training, not deletion or a claim that a biological specimen was invalid.',
      '- Boundary/contrast/focus thresholds are conservative dataset engineering screens. Very pale legitimate pads may remain unconfirmed; exclusions and selection bias must be disclosed.',
      '- The visual spot-check found an off-strip first ROI and a partial endpoint ROI. Background-presence and color-boundary checks reject these rather than accepting the detector count as proof.',
      '- Exact current Dart color math is used for admitted feature rows. Native full-photo checks and context-crop results are retained separately.',
      '- Original binary BATCH values are never converted or modified. Their photos remain available for geometry research; a separately traceable per-pad reference is needed for semiquantitative training.',
      '- Historical color-chart cyclic labels are not measured specimen observations. Duplicate exports and repeated photographs do not add biological independence.',
      '- Cross-batch identity and clinical reference adjudication remain unresolved. The inspected historical data cannot become a new untouched external validation set.',
      '- No confidence threshold, support rejection, pad order, physical reading-time rule, or clinical safety gate is relaxed.', '',
      'Private local outputs: `PHOTO_REVIEW.html`, `FINAL_PHOTO_AUDIT.csv`, `CLEAN_FEATURES.csv`, `cleaned/`, original/crop runtime receipts and protected-input snapshots. '
      'Aggregate comparison details: `DEVELOPMENT_COMPARISON.json`. Reference trace: `LABEL_SOURCE_REVIEW.md`.', '']
    (out/'REPORT.md').write_text('\n'.join(lines),encoding='utf-8')
    print(out/'REPORT.md')


if __name__=='__main__':run()
