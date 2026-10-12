# User-friendly UI simplification — 1.5.16+34

This is a subsequent UI/content version following the owner-supplied recommendation. Prior MedTech/IT ratings and signatures do not automatically apply to it. Record the actual repository commit/tag/version and APK hash reviewed, and run a short usability regression before using new screenshots in the manuscript. No evaluation scores, approvals or device passes are invented.

## Implemented screens

| Area / changed source | Result |
|---|---|
| Home (`pages/home_page.dart`) | Larger aligned logo, no workspace subtitle or process-line footer, concise preparation bullets, prominent Start Scan and protected Recent Scans retained |
| Information (`pages/about_page.dart`) | About, How to Use, Safety and Limitations, Privacy and Data; optional Research Information opens the existing technical performance page |
| Photo review (`widgets/scan_provenance_dialog.dart`) | Compact Review Photo dialog; 30/40/45/60 seconds, unknown or custom time; explicit current-specimen confirmation; brief duplicate notice; code and photo metadata under optional Research Details |
| Readings (`pages/results_page.dart`, `widgets/dipstick_results_table.dart`) | One short status; no repeated Image Review Only rows or confidence paragraphs; unconfirmed confidence, timing or metadata renders Uncertain; original classifications remain stored and available in research details |
| Summary (`pages/overall_results_page.dart`) | Completeness/reliability status, next action and visible safety warnings first, then plain UTI information and kidney follow-up; no normal-screen probability, LR, model ID or raw evidence strings |
| Kidney follow-up (`pages/renal_results_page.dart`) | Results Considered; unreliable protein/blood shown as Unable to confirm; technical profile/rule IDs moved to research details; symptom-based consultation guidance retained alongside retake advice |
| Checklist (`pages/symptom_checklist_page.dart`, summary) | Shorter labels, no conflicting symptom/selected-item ratios; response review distinguishes Yes, No, Not sure, not asked/unanswered and legacy Not confirmed |
| Research (`widgets/research_details.dart`, `widgets/scan_context_notice.dart`) | Optional raw values, references, vote confidence, distances, original rejection reason, reported timing/specimen metadata, Bayesian percentage/prior/LRs/model identifiers and renal rule IDs; only essential missing/old/duplicate context notices remain outside the drawer |

## Safety and research boundary

The UI does not promote unknown/unreliable evidence into confirmed results. A specimen code is optional for starting photo review, but the existing current-specimen gate still requires it, known timing, explicit confirmation and completed duplicate checks. No automatic code or current-specimen confirmation was created. Unknown timing remains review only; each pad retains its own reading-time restriction.

The Bayesian calculation is unchanged, but it is not locally clinically calibrated. Numerical percentages therefore appear only in the optional unvalidated Research Details drawer, rather than as a patient's normal-screen UTI probability. Eligibility and reliable-input gates still determine whether a calculation exists. Saved estimates are shown as recorded in that drawer, with no overwrite or silent recalculation of history.

Completeness labels describe whether required information can support screening, not disease presence or absence. Serious symptoms and escalation remain independent of scan success. Raw model categories and technical identifiers are preserved for research, even when the patient-facing row says Uncertain.

All research drawers stay inside their existing screen. Saved-history authentication, background locking, session expiry and secure-window protection continue to cover their contents; an extra unprotected route was not introduced for private results.

## Unchanged core and verification

All existing `lib/models`, `lib/services` and `assets` files are compared byte-for-byte with the pre-redesign baseline. Classifier, preprocessing, physical pad order, feature extraction, image-quality thresholds, Bayesian equations/priors/LRs, clinical/renal rules, reliability/timing/eligibility, provenance checks and local storage/security are unchanged. The app version and UI source/tests changed; release tooling now accepts dated evidence folders instead of assuming October 12.

Automated checks cover unknown timing, code omission, valid explicit metadata, duplicates, small-phone/large-text dialogs, unconfirmed kidney readings, hidden patient-facing technical data, preserved Bayesian figures, explicit unknown checklist answers, saved-history research locking and Home navigation. Phone screenshots use the real bundled Poppins fonts and are visually inspected.

Exact source/APK checks and test results are in the current signed build receipt. Actual two-phone testing, signed professional review, manufacturer/IFU reconciliation, independent performance/calibration evidence and manuscript source revision remain pending. This UI update does not resolve those external evidence gaps or claim production/clinical readiness.
