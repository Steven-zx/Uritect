"""Record and verify read-only CSV inputs, archive hashes and installed-model assets."""
import argparse
import json
from pathlib import Path

from audit_legacy_dataset import DEFAULT_OUT, OLD, ROOT, dump, file_digest


def snapshot(out):
    destination = out / 'PROTECTED_INPUTS.json'
    if destination.exists():
        raise RuntimeError('Protected-input snapshot already exists; do not overwrite it')
    paths = list((ROOT / 'pipeline/dataset').rglob('*.csv'))
    paths += list((OLD / 'events').glob('*/*.csv'))
    paths += list((OLD / 'manifests').glob('*.csv'))
    paths += list((OLD / 'labels').glob('*.csv'))
    paths += [ROOT / 'uritect_app/assets/production_semiquant_model.json',
              ROOT / 'uritect_app/assets/training_support_policy.json',
              ROOT / 'uritect_app/lib/services/local_scan_analysis_service.dart']
    # All supplied binary and semiquant values remain byte-for-byte unchanged.
    records = [dict(path=str(p), sha256=file_digest(p)) for p in sorted(set(paths)) if p.is_file()]
    dump(destination, records)
    print(f'Recorded {len(records)} protected inputs')


def verify(out):
    inventory = json.loads((out / 'INVENTORY.json').read_text())
    protected = json.loads((out / 'PROTECTED_INPUTS.json').read_text())
    entries = {r['path']: r['sha256'] for r in protected + inventory['references'] + inventory['archives']}
    supplementary=out/'UNPACKED_PHOTO_AUDIT.json'
    if supplementary.exists():
        for row in json.loads(supplementary.read_text()):
            for path in row.get('original_paths',[]):entries[path]=row['image_sha256']
    failures = [p for p, sha in entries.items() if not Path(p).exists() or file_digest(p) != sha]
    dump(out / 'SOURCE_INTEGRITY.json', dict(checked_files=len(entries), all_unchanged=not failures,
         failed_count=len(failures), binary_values_modified=False if not failures else None,
         scope='Archives and original reference files against inventory-time hashes; additional CSVs/model assets against protection snapshot. No original is edited.'))
    if failures:
        raise RuntimeError(f'Protected source changed: {failures}')
    print(f'Verified {len(entries)} unchanged input files')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['snapshot', 'verify'])
    parser.add_argument('--out', type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    (snapshot if args.phase == 'snapshot' else verify)(args.out)
