"""Verify sealed artifacts and detect source drift, without asserting clinical acceptance."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from build_final_release_manifest import ROOT, OUTPUT, sha256, inventory

def safe_path(root, relative):
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError('Artifact path escapes project: ' + relative)
    return path

def verify_entries(root, entries):
    failures = []
    for item in entries:
        try:
            path = safe_path(root, item['path'])
        except (ValueError, KeyError) as error:
            failures.append(str(error))
            continue
        if not path.is_file():
            failures.append('missing: ' + item['path'])
        elif path.stat().st_size != item['bytes'] or sha256(path) != item['sha256']:
            failures.append('artifact mismatch: ' + item['path'])
    return failures

def verify(manifest, root=ROOT, current_inventory=None):
    data = json.loads(manifest.read_text(encoding='utf-8'))
    if data.get('schema_version') != 2:
        return ['Legacy manifest is not the current release freeze.']
    failures = verify_entries(root, data['files'] + [data['apk'], data['source_snapshot']])
    if failures:
        return failures
    frozen = json.loads(safe_path(root, data['source_snapshot']['path']).read_text(encoding='utf-8'))
    failures += verify_entries(root, frozen['files'] + [frozen['archive']])
    if current_inventory is not None and current_inventory != frozen['files']:
        failures.append('Source drift: added, removed or changed app input.')
    return failures

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, default=OUTPUT)
    args = parser.parse_args()
    failures = verify(args.manifest, current_inventory=inventory())
    if failures:
        raise SystemExit('\n'.join(failures))
    print('Release artifacts and source freeze verified. Device/clinical acceptance is a separate gate.')

if __name__ == '__main__':
    main()
