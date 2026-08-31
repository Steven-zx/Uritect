from __future__ import annotations

from typing import Optional

ANALYTE_LEVEL_SCHEMA: dict[str, list[str]] = {
    "Leukocytes": ["Neg", "Trace 15", "Small 70", "Moderate 125", "Large 500"],
    "Nitrite": ["Neg", "Positive"],
    "Urobilinogen": ["3.2", "16", "32", "64", "128"],
    "Protein": ["Neg", "Trace", "0.3", "1.0", "3.0", ">=20.0"],
    "pH": ["5.0", "6.0", "6.5", "7.0", "7.5", "8.0", "8.5"],
    "Blood": ["Neg", "Non-hemolyzed 10", "Hemolyzed 10", "Small 25", "Moderate 80", "Large 200"],
    "Specific Gravity": ["1.000", "1.005", "1.010", "1.015", "1.020", "1.025", "1.030"],
    "Ketone": ["Neg", "Trace 0.5", "Small 1.5", "Moderate 4.0", "8.0", "Large 16"],
    "Bilirubin": ["Neg", "Small 17", "Moderate 50", "Large 100"],
    "Glucose": ["Neg", "Trace 5", "15 +", "30 ++", "60 +++", "110 ++++"],
}

ANALYTE_ORDER = tuple(ANALYTE_LEVEL_SCHEMA.keys())

_LEVEL_ALIASES: dict[str, dict[str, str]] = {
    "Leukocytes": {
        "negative": "Neg",
        "neg": "Neg",
        "trace": "Trace 15",
        "trace15": "Trace 15",
        "small": "Small 70",
        "small70": "Small 70",
        "moderate": "Moderate 125",
        "moderate125": "Moderate 125",
        "large": "Large 500",
        "large500": "Large 500",
    },
    "Nitrite": {
        "negative": "Neg",
        "neg": "Neg",
        "pos": "Positive",
        "positive": "Positive",
    },
    "Urobilinogen": {
        "normal": "3.2",
        "neg": "3.2",
    },
    "Protein": {
        "negative": "Neg",
        "neg": "Neg",
        "trace": "Trace",
        "1": "1.0",
        "3": "3.0",
        "20": ">=20.0",
        "20.0": ">=20.0",
        ">20": ">=20.0",
        ">=20": ">=20.0",
    },
    "pH": {},
    "Blood": {
        "negative": "Neg",
        "neg": "Neg",
        "10 non-hemolyzed": "Non-hemolyzed 10",
        "nonhemolyzed 10": "Non-hemolyzed 10",
        "10 hemolyzed": "Hemolyzed 10",
        "hemolyzed 10": "Hemolyzed 10",
        "small": "Small 25",
        "moderate": "Moderate 80",
        "large": "Large 200",
    },
    "Specific Gravity": {
        "1.00": "1.000",
        "1.01": "1.010",
        "1.02": "1.020",
        "1.03": "1.030",
        "1010.0": "1.010",
    },
    "Ketone": {
        "negative": "Neg",
        "neg": "Neg",
        "trace": "Trace 0.5",
        "small": "Small 1.5",
        "moderate": "Moderate 4.0",
        "large": "Large 16",
        "16": "Large 16",
    },
    "Bilirubin": {
        "negative": "Neg",
        "neg": "Neg",
        "small": "Small 17",
        "moderate": "Moderate 50",
        "large": "Large 100",
    },
    "Glucose": {
        "negative": "Neg",
        "neg": "Neg",
        "trace": "Trace 5",
        "trace 5": "Trace 5",
        "5 trace": "Trace 5",
        "15+": "15 +",
        "15": "15 +",
        "30++": "30 ++",
        "30": "30 ++",
        "60+++": "60 +++",
        "60": "60 +++",
        "110++++": "110 ++++",
        "110": "110 ++++",
    },
}


def _normalize_token(value: str) -> str:
    return " ".join(value.strip().lower().replace("µ", "u").split())


def canonicalize_level(analyte: str, level: str) -> Optional[str]:
    if analyte not in ANALYTE_LEVEL_SCHEMA:
        return None

    trimmed = level.strip()
    if not trimmed:
        return None

    allowed = ANALYTE_LEVEL_SCHEMA[analyte]

    for candidate in allowed:
        if _normalize_token(candidate) == _normalize_token(trimmed):
            return candidate

    alias_map = _LEVEL_ALIASES.get(analyte, {})
    alias_hit = alias_map.get(_normalize_token(trimmed))
    if alias_hit is not None:
        return alias_hit

    return None


def is_valid_level(analyte: str, level: str) -> bool:
    return canonicalize_level(analyte, level) is not None
