"""Conservative filename-inferred identities; not verified patient identifiers."""
import re


def specimen_group(row):
    event = row.get('event_id', '').strip()
    batch = row.get('batch_id', '').strip()
    if not batch:
        raise ValueError('Batch provenance is required for inferred identity')
    if re.fullmatch(r'LAUAAN-P\d+-L(?:2700|4000|5500)', event):
        participant = re.search(r'P\d+', event)[0]
    elif re.fullmatch(r'uritect_\d{4}-\d+-\d+_Cabatuan_[^_]+_(?:Cool|Warm|Daylight)', event):
        participant = event.rsplit('_', 2)[1]
    else:
        raise ValueError(f'Unrecognized identity format: {event}')
    return f'{batch}|{participant}'
