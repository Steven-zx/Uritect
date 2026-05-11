import json
m = json.load(open('pipeline/output/knn_reference_map.json'))
analyte = m['analytes']['Leukocytes']
print(f'Type: {type(analyte)}')
if isinstance(analyte, list):
    print(f'List length: {len(analyte)}')
    print(f'First level item type: {type(analyte[0]) if analyte else "empty"}')
    if analyte and isinstance(analyte[0], dict):
        print(f'First level item keys: {list(analyte[0].keys())[:5]}')
elif isinstance(analyte, dict):
    print(f'Keys: {list(analyte.keys())[:5]}')
