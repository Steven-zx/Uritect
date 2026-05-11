#!/usr/bin/env python3
"""Wrapper to build LAB features by calling the ingest pipeline with --feature-space lab.

This script is a convenience so users can quickly regenerate LAB features without
remembering the exact ingest command.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

DEFAULT_OUTPUT = Path(__file__).parent / "dataset" / "features_lab.csv"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build LAB feature CSV via ingest.py")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--venv-python", type=str, default=sys.executable, help="Python executable to run ingest with")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    ingest = Path(__file__).parent / "ingest.py"
    if not ingest.exists():
        raise SystemExit(f"ingest.py not found at {ingest}")

    cmd = [args.venv_python, str(ingest), "--feature-space", "lab", "--output", str(args.output)]
    print("Running:", " ".join(cmd))
    rc = subprocess.run(cmd)
    if rc.returncode != 0:
        raise SystemExit(f"ingest.py failed with exit code {rc.returncode}")

    print(f"Saved LAB features -> {args.output.resolve()}")


if __name__ == "__main__":
    main()
