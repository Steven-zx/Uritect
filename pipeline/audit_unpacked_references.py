"""Include unpacked chart originals; archived duplicates do not gain training weight."""
import json
from pathlib import Path
from audit_legacy_dataset import DEFAULT_OUT, OLD, EXT, digest, dump, process_photo


def run(out=DEFAULT_OUT):
    inventory = json.loads((out / 'INVENTORY.json').read_text())
    known = {r['image_sha256'] for r in inventory['photos']}
    additional = {}
    occurrences = 0
    for folder in ['events', 'jpg_colorwheel', 'tmp_colorwheel']:
        for path in (OLD / folder).rglob('*'):
            if not path.is_file() or path.suffix.lower() not in EXT:
                continue
            occurrences += 1
            key = digest(path.read_bytes())
            if key in known:
                continue
            additional.setdefault(key, []).append(str(path))
    records = []
    for key, paths in additional.items():
        # Any unexpected unpacked specimen requires its own reference trace.
        # Never convert original Normal/Abnormal observations into categories.
        chart = all('colorwheel' in p.lower() for p in paths)
        primary = dict(source_path=paths[0], member=Path(paths[0]).name,
            family='COLORWHEEL' if chart else 'UNPACKED_REFERENCE_UNVERIFIED',
            group='', subject_alias='', labels={},
            label_status='reference_chart_not_specimens' if chart else 'original_binary_or_missing_reference')
        photo = dict(image_sha256=key, eligible_labels=False, reference_conflict=False, primary=primary)
        record = process_photo((photo, str(out)))
        record['original_paths'] = paths
        records.append(record)
    dump(out / 'UNPACKED_PHOTO_AUDIT.json', records)
    dump(out / 'UNPACKED_SUMMARY.json', dict(unpacked_occurrences=occurrences,
        additional_unique_photos=len(records), additional_charts=sum(r['family']=='COLORWHEEL' for r in records),
        archived_duplicates_collapsed=True, original_binary_values_modified=False))
    print(f'Audited {len(records)} additional unpacked photos; originals untouched')


if __name__ == '__main__':
    run()
