import csv
with open('pipeline/dataset/features_lab.csv', newline='', encoding='utf-8') as f:
    rows = list(csv.DictReader(f))
    first_keys = set(rows[0].keys())
    lab_cols = [c for c in first_keys if c.endswith('_l')]
    hsv_cols = [c for c in first_keys if c.endswith('_h')]
    print(f'Total columns: {len(first_keys)}')
    print(f'LAB columns ending in _l: {len(lab_cols)} samples: {lab_cols[:3]}')
    print(f'HSV columns ending in _h: {len(hsv_cols)} samples: {hsv_cols[:3] if hsv_cols else "None"}')
    detected = 'lab' if lab_cols else ('hsv' if hsv_cols else 'unknown')
    print(f'Detection result: {detected}')
