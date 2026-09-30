#!/usr/bin/env python3
"""Create a checksum manifest for the authoritative URITECT release files."""

from __future__ import annotations

import hashlib
import json
import pathlib
from datetime import datetime, timezone


ROOT = pathlib.Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "release" / "URITECT_FINAL_RELEASE_MANIFEST.json"
FILES = [
    "output/apk/Uritect_v1.3.0_bayesian_v1.1_renal_v1.1_release.apk",
    "uritect_app/assets/production_semiquant_model.json",
    "pipeline/output/semiquant_models/semiquant_models_metadata.json",
    "pipeline/output/production_grouped_evaluation.json",
    "pipeline/output/production_grouped_metrics_complete.json",
    "pipeline/output/whole_scan_optimization_final_knn_grouped.json",
    "docs/URITECT_Bayesian_UTI_Scoring_System_v1.1.md",
    "docs/URITECT_Renal_Rule_Specification_v1.1.md",
    "docs/ANDROID_RELEASE_SIGNING.md",
    "uritect_app/lib/models/screening_fusion.dart",
    "uritect_app/lib/models/renal_followup.dart",
    "uritect_app/lib/models/saved_scan_record.dart",
    "uritect_app/lib/pages/symptom_checklist_page.dart",
    "uritect_app/lib/pages/overall_results_page.dart",
    "uritect_app/pubspec.yaml",
    "uritect_app/android/app/build.gradle.kts",
    "uritect_app/android/app/src/main/AndroidManifest.xml",
    "output/pdf/URITECT_Bayesian_UTI_Scoring_System_v1.1.pdf",
    "output/pdf/URITECT_Bayesian_Parameter_Validation_Form_v1.2.pdf",
    "output/pdf/URITECT_Renal_Physician_Implementation_Signoff_v1.1.pdf",
    "output/pdf/URITECT_ISO25010_MedTech_App_Evaluation_v1.0.pdf",
    "output/pdf/URITECT_Final_Project_Handoff_v1.0.pdf",
    "output/forms/URITECT_ISO25010_MedTech_App_Evaluation_Data_Template.csv",
    "pipeline/analyze_medtech_app_evaluation.py",
    "pipeline/verify_final_release_manifest.py",
]


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def main() -> None:
    missing = [relative for relative in FILES if not (ROOT / relative).is_file()]
    if missing:
        raise SystemExit(f"Cannot build final manifest; missing: {missing}")
    entries = []
    for relative in FILES:
        path = ROOT / relative
        entries.append(
            {
                "path": relative.replace("\\", "/"),
                "bytes": path.stat().st_size,
                "sha256": sha256(path),
            }
        )
    manifest = {
        "release": "URITECT 1.3.0 - Bayesian UTI v1.1 - Renal rules v1.1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "android_application_id": "ph.edu.wvsu.uritect",
        "android_version": {"name": "1.3.0", "code": 4},
        "release_signing_certificate_sha256": "15D1138DCE077ADA624A140B3A145343D1A48305FD0847E9002869E488F19D39",
        "production_model_version": "production_semiquant_knn_markerless_roi_topfix_v3_20260908",
        "bayesian_model_version": "uti_bayesian_lr_v1_1_20260926",
        "renal_rule_version": "renal_followup_rules_v1.1_20260919",
        "files": entries,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("w", encoding="utf-8") as stream:
        json.dump(manifest, stream, indent=2)
    print(f"Manifest: {OUTPUT}")


if __name__ == "__main__":
    main()
