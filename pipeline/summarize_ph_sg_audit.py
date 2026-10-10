"""Development-only diagnostics and reproducible visual review contact sheets."""
import csv
import json
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from sklearn.metrics import pairwise_distances
from semiquant_schema import canonicalize_level

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'pipeline/output/ph_sg_error_audit_2026-10-11'


def main():
    rows = list(csv.DictReader((OUT / 'FOCUSED_REVIEW.csv').open(encoding='utf-8')))
    predictions = list(csv.DictReader((OUT / 'NESTED_PREDICTIONS.csv').open(encoding='utf-8')))
    manifest = json.loads((ROOT / 'pipeline/output/knn_improvement_2026-10-11/SPLIT_MANIFEST.json').read_text())
    events = manifest['events']
    indices = {e['event_id']: i for i, e in enumerate(events)}
    features = np.load(OUT / 'TARGET_FEATURES.npz')
    summary = {}
    with (ROOT / 'pipeline/output/knn_improvement_2026-10-11/GROUPED_DATASET.csv').open(encoding='utf-8-sig') as f:
        source_rows = list(csv.DictReader(f))
    for ai, analyte in enumerate(('pH', 'Specific Gravity')):
        pp = [p for p in predictions if p['analyte'] == analyte]
        ids = [indices[p['event_id']] for p in pp]
        groups = np.array([p['group'] for p in pp])
        labels = np.array([p['reference'] for p in pp])
        diagnostics = {}
        for recipe in ('runtime_normalized', 'runtime_raw', 'backing_raw', 'raw_lab'):
            x = features[recipe][ids, ai]
            d = pairwise_distances(x)
            # Raw distances are diagnostic within one recipe, not comparable across recipes.
            d[groups[:, None] == groups[None, :]] = np.inf
            nearest = d.argmin(axis=1)
            diagnostics[recipe] = {
                'nearest_other_group_label_disagreement': float(np.mean(labels != labels[nearest])),
                'per_reference_disagreement': {str(l): float(np.mean(labels[labels == l] != labels[nearest][labels == l])) for l in sorted(set(labels))},
            }
        wrong = [p for p in pp if p['reference'] != p['baseline_prediction']]
        summary[analyte] = {
            'development_events': len(pp),
            'baseline_predicted_counts': dict(Counter(p['baseline_prediction'] for p in pp)),
            'baseline_error_pairs': dict(Counter(p['reference'] + ' -> ' + p['baseline_prediction'] for p in wrong)),
            'nested_predicted_counts': dict(Counter(p['nested_prediction'] for p in pp)),
            'feature_neighborhoods': diagnostics,
        }
        reference_rows = [r for r in source_rows if r['analyte'] == analyte]
        grouped_labels = {}
        for r in reference_rows:
            grouped_labels.setdefault(r['specimen_group'], set()).add(r['level'])
        summary[analyte]['reference_integrity'] = {
            'retained_reference_counts': dict(Counter(r['level'] for r in reference_rows)),
            'raw_to_canonical_mismatches': sum(canonicalize_level(analyte, r['label_raw'].split(':', 1)[-1]) != r['level'] for r in reference_rows),
            'inferred_groups_with_conflicting_reference_labels': [g for g, levels in grouped_labels.items() if len(levels) > 1],
            'scope': 'Recorded-label consistency only; does not verify chart reading, laboratory reference, or reaction time.',
        }
        if analyte == 'Specific Gravity':
            summary[analyte]['errors_within_one_0_005_step'] = sum(abs(float(p['reference']) - float(p['baseline_prediction'])) <= .005001 for p in wrong)
            summary[analyte]['total_errors'] = len(wrong)
        rr = [r for r in rows if r['analyte'] == analyte]
        chosen = []
        def add(candidates, count):
            for r in candidates:
                if r not in chosen:
                    chosen.append(r)
                    count -= 1
                    if count == 0:
                        break
        failed = [r for r in rr if r['baseline_wrong'] == 'True']
        add(sorted(failed, key=lambda r: float(r['value_range']), reverse=True), 4)
        add(sorted(failed, key=lambda r: float(r['center_shift_pixels']), reverse=True), 4)
        add([r for r in failed if r['boundary_status'] != 'color_boundary_supported'], 4)
        for label in sorted(set(r['reference'] for r in failed)):
            add([r for r in failed if r['reference'] == label], 1)
        add([r for r in rr if r['baseline_wrong'] == 'False'], 4)
        canvas = Image.new('RGB', (1200, ((len(chosen) + 3) // 4) * 280), 'white')
        draw = ImageDraw.Draw(canvas)
        for n, r in enumerate(chosen):
            x, y = n % 4 * 300, n // 4 * 280
            photo = Image.open(OUT / r['context']).convert('RGB')
            photo.thumbnail((290, 210))
            canvas.paste(photo, (x + (300 - photo.width) // 2, y))
            draw.text((x + 5, y + 215), r['event_id'], fill='black')
            draw.text((x + 5, y + 232), f"{analyte}: {r['reference']} -> {r['baseline_prediction']}", fill='black')
            draw.text((x + 5, y + 249), r['boundary_status'], fill='black')
        name = 'ph' if ai == 0 else 'sg'
        canvas.save(OUT / 'image_evidence' / f'{name}_review_contact_sheet.png')
        summary[analyte]['contact_sheet_events'] = [r['event_id'] for r in chosen]
    (OUT / 'ERROR_CAUSE_DIAGNOSTICS.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
