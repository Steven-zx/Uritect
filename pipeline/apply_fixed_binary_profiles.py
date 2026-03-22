#!/usr/bin/env python3
"""
Apply fixed per-analyte semiquant profiles to converted binary packages.

Targets ZIPs that were converted from binary labels, then rewrites training_index.csv
so each row receives the exact user-provided Normal/Abnormal analyte levels.
"""

from __future__ import annotations

import argparse
import csv
import io
import pathlib
import zipfile

from semiquant_schema import ANALYTE_ORDER, canonicalize_level


NORMAL_PROFILE_RAW = {
    "Leukocytes": "Trace 15",
    "Nitrite": "Neg",
    "Urobilinogen": "Neg",
    "Protein": "Neg",
    "pH": "5.0",
    "Blood": "Neg",
    "Specific Gravity": "1.025",
    "Ketone": "Neg",
    "Bilirubin": "Neg",
    "Glucose": "Neg",
}

ABNORMAL_PROFILE_RAW = {
    "Leukocytes": "Small 70",
    "Nitrite": "Positive",
    "Urobilinogen": "16",
    "Protein": "20++",
    "pH": "8.5",
    "Blood": "10 trace",
    "Specific Gravity": "1.005",
    "Ketone": "Small",
    "Bilirubin": "Large 100",
    "Glucose": "30++",
}


def _canonical_profile(raw: dict[str, str]) -> dict[str, str]:
    out: dict[str, str] = {}
    for analyte in ANALYTE_ORDER:
        raw_level = raw.get(analyte, "")

        token = raw_level.strip().lower().replace(".", "")
        if token == "20++":
            raw_level = ">=20.0"
        elif token == "30++":
            raw_level = "30 ++"
        elif token in {"neg", "negative"}:
            raw_level = "Neg"

        if analyte == "Blood" and raw_level.strip().lower() == "10 trace":
            raw_level = "Non-hemolyzed 10"

        level = canonicalize_level(analyte, raw_level)
        if level is None:
            raise ValueError(f"Invalid profile level for {analyte}: {raw_level!r}")
        out[analyte] = level
    return out


NORMAL_PROFILE = _canonical_profile(NORMAL_PROFILE_RAW)
ABNORMAL_PROFILE = _canonical_profile(ABNORMAL_PROFILE_RAW)

BINARY_NORMAL_KEYS = {"normal", "negative", "class1", "class_1", "class 1", "1"}
BINARY_ABNORMAL_KEYS = {"abnormal", "positive", "class2", "class_2", "class 2", "2"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Apply fixed Normal/Abnormal semiquant profiles to ZIPs")
    parser.add_argument(
        "--packages-dir",
        type=pathlib.Path,
        required=True,
        help="Directory with package ZIP files",
    )
    parser.add_argument(
        "--pattern",
        default="*_SEMIQUANT_FROM_BINARY.zip",
        help="ZIP pattern to patch (default: *_SEMIQUANT_FROM_BINARY.zip)",
    )
    return parser.parse_args()


def _row_binary_state(row: dict[str, str], zip_name: str) -> str | None:
    for key in ("class_label", "label", "label_canonical", "label_raw", "class_id"):
        value = str(row.get(key, "")).strip()
        if not value:
            continue
        lowered = value.lower()
        if lowered in BINARY_NORMAL_KEYS or value == "1":
            return "normal"
        if lowered in BINARY_ABNORMAL_KEYS or value == "2":
            return "abnormal"

    name = zip_name.lower()
    if "_normal_" in name or name.endswith("_normal.zip"):
        return "normal"
    if "_abnormal_" in name or name.endswith("_abnormal.zip"):
        return "abnormal"
    if "normal" in name and "abnormal" not in name:
        return "normal"
    if "abnormal" in name:
        return "abnormal"

    return None


def _apply_profile(row: dict[str, str], profile: dict[str, str]) -> dict[str, str]:
    out = dict(row)
    for analyte in ANALYTE_ORDER:
        col = f"{analyte.lower().replace(' ', '_')}_level"
        out[col] = profile[analyte]

    out["label"] = ""
    return out


def patch_zip(zip_path: pathlib.Path) -> tuple[int, int, int]:
    with zipfile.ZipFile(zip_path, "r") as src:
        names = set(src.namelist())
        if "training_index.csv" not in names:
            return 0, 0, 0

        with src.open("training_index.csv") as f:
            rows = list(csv.DictReader(io.TextIOWrapper(f, encoding="utf-8")))

        if not rows:
            return 0, 0, 0

        patched_rows: list[dict[str, str]] = []
        normal_count = 0
        abnormal_count = 0

        for row in rows:
            state = _row_binary_state(row, zip_path.name)
            if state == "normal":
                patched_rows.append(_apply_profile(row, NORMAL_PROFILE))
                normal_count += 1
            elif state == "abnormal":
                patched_rows.append(_apply_profile(row, ABNORMAL_PROFILE))
                abnormal_count += 1
            else:
                patched_rows.append(dict(row))

        fieldnames = list(patched_rows[0].keys())
        for analyte in ANALYTE_ORDER:
            col = f"{analyte.lower().replace(' ', '_')}_level"
            if col not in fieldnames:
                fieldnames.append(col)

        temp_zip = zip_path.with_suffix(".tmp.zip")
        with zipfile.ZipFile(temp_zip, "w", compression=zipfile.ZIP_DEFLATED) as dst:
            for info in src.infolist():
                if info.filename == "training_index.csv":
                    continue
                dst.writestr(info, src.read(info.filename))

            buffer = io.StringIO()
            writer = csv.DictWriter(buffer, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(patched_rows)
            dst.writestr("training_index.csv", buffer.getvalue().encode("utf-8"))

    zip_path.unlink(missing_ok=True)
    temp_zip.replace(zip_path)

    return len(patched_rows), normal_count, abnormal_count


def main() -> None:
    args = parse_args()
    packages_dir = args.packages_dir.resolve()

    if not packages_dir.exists():
        raise FileNotFoundError(f"Packages dir not found: {packages_dir}")

    zip_paths = sorted(packages_dir.glob(args.pattern))
    if not zip_paths:
        print(f"No files matched: {args.pattern}")
        return

    print("Applying fixed semiquant profiles:")
    print(f"  Normal:   {NORMAL_PROFILE}")
    print(f"  Abnormal: {ABNORMAL_PROFILE}")

    total_rows = 0
    total_normals = 0
    total_abnormals = 0

    for zip_path in zip_paths:
        rows, normals, abnormals = patch_zip(zip_path)
        total_rows += rows
        total_normals += normals
        total_abnormals += abnormals
        print(
            f"[OK] {zip_path.name} | rows={rows}, normal={normals}, abnormal={abnormals}"
        )

    print("\nDone.")
    print(f"Patched ZIPs: {len(zip_paths)}")
    print(f"Rows: {total_rows} (normal={total_normals}, abnormal={total_abnormals})")


if __name__ == "__main__":
    main()
