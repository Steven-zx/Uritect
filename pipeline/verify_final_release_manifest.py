#!/usr/bin/env python3
"""Verify every artifact recorded in the final URITECT release manifest."""

from __future__ import annotations

import hashlib
import json
import pathlib


ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "output" / "release" / "URITECT_FINAL_RELEASE_MANIFEST.json"


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def main() -> None:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    failures: list[str] = []
    for entry in data["files"]:
        path = ROOT / entry["path"]
        if not path.is_file():
            failures.append(f"missing: {entry['path']}")
            continue
        actual_size = path.stat().st_size
        actual_hash = sha256(path)
        if actual_size != entry["bytes"]:
            failures.append(
                f"size mismatch: {entry['path']} "
                f"expected {entry['bytes']}, got {actual_size}"
            )
        if actual_hash != entry["sha256"]:
            failures.append(
                f"hash mismatch: {entry['path']} "
                f"expected {entry['sha256']}, got {actual_hash}"
            )
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"Verified {len(data['files'])} release files against {MANIFEST}")


if __name__ == "__main__":
    main()
