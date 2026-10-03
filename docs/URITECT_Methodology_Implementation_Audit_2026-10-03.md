# URITECT methodology and implementation audit — 2026-10-03

## Outcome and scope

All 15 requested issues were checked against source, frozen specifications, current model asset and tests. This is an engineering audit, not statistical or clinical validation. Priors, LR values, LR ordering, visual classifier and renal rule thresholds/action priority were not adjusted. Issues 1–3 remain open for a statistician/biostatistician. Two-medtech content review cannot establish posterior calibration.

Installed phone APK: retake-only pilot 1.4.0+6 (user confirmed NEW SCAN now works). The source fixes described below are not yet installed. The original release manifest remains the 1.4.0+5 snapshot; it is not a checksum manifest for this edited source. No edited specification PDF, final manuscript or final release synchronization is claimed.

## Issue-by-issue findings

| Issue | Engineering finding / action | Remaining boundary |
| --- | --- | --- |
| 1. Male overlapping LRs | Confirmed one first-matching factor only: both positive 5.14; nitrite threshold 4.87; LE threshold 1.65; both confirmed negative 0.35. Added all-branch regression coverage and clarified the changed conditioning after excluding stronger branches. | Research approximation; ordered selection does not establish exact-pattern validity. Statistical decision required. |
| 2. Male prior | Exact calculation remains 97/186; display corrected from 52% rounding to 52.2%. Spec now explicitly identifies younger-subgroup prior plus broader-cohort LRs. | Neither local male prevalence nor an exact age-18–64 estimate; cross-age/setting transportability requires review. |
| 3. Female multiplication | Confirmed at most one dipstick and one symptom factor; no extra factors added. Code/spec explicitly identify cross-group multiplication as an unestablished statistical assumption. | Conditional independence and combined-model calibration are not demonstrated by the hierarchy. |
| 4. Female Trace 15 | Exact test: NIT negative + BLD negative + LE Trace 15 yields no dipstick factor. Other usable evidence can still contribute when the scan is reliable. | No threshold change; Trace is neither source-positive nor confirmed negative. |
| 5. Sex-specific LE mapping | Separate positive functions verified: female Small 70/Moderate 125/Large 500; male additionally Trace 15. | Physical IFU/source-category equivalence still needs content review. |
| 6. Model separation/history | Male branches return before female factors; own prior/gates/model version. JSON preserves prior/posterior/factors/status/model. Added interpretation-policy version. Fixed history UI to show recorded posterior rather than silently recomputing it. | Follow-up guidance is separately re-evaluated under current rules and labelled accordingly. Missing historical posterior metadata is not fabricated. |
| 7. Unknown inputs | Empty/missing/Unknown/Unavailable/Unreliable labels receive no analyte update. Typed unreliable evidence is excluded. Unselected symptoms do not generate negative symptom LRs. Added explicit tests. | A usable independent input may still contribute if the whole scan is valid; no general conversion of unknown to negative. |
| 8. Wording | Female footer now says provisional/literature-derived/not locally calibrated; male research-approximation disclaimer retained. No clinical probability bands. Phone screenshot golden updated for intentional text change. | Test goldens use Flutter test fonts; device visual QA for these new source changes remains pending. |
| 9. Separate engines | Renal posterior does not exist; renal rule engine never consumes UTI percentage. No arithmetic combination of UTI and renal findings. | Shared safety blocking uses existing renal PROMPT_CONSULT action only, not renal evidence as Bayesian factors. |
| 10. Safety/interference | Fixed cannot-hydrate/medicate and confusion/fainting/weakness flags to stop ordinary posterior. Full-scan pathway also blocks ordinary estimates for existing renal prompt-safety rules. Existing renal visible-blood/clot/obstruction, contamination, repeat/microscopy and priorities verified. | Pregnancy blocks female eligibility; no new pregnancy renal rule invented. Clinical review must settle any desired suppression of female dipstick-blood LR under menstruation/contamination; no LR was modified for that question. |
| 11. Eligibility | Added human-readable contract pointing to executable confirmation lists. Each required confirmation tested as missing. Male UI clarifies dysuria/frequency/urgency are required; other symptoms still inform follow-up. | Editable Chapter 3 and diagrams are not in the repository, so their exact alignment cannot be verified here. |
| 12. IDs | Explicit crosswalk added to spec/form: parameter IDs and branch IDs differ. | Use document + ID in review records; do not refer to M03 as branch M3. |
| 13. Performance | Frozen claims preserved: 82.52% individual-analyte, 17.18% all-ten-correct whole-scan. Neither is disease accuracy or Bayesian calibration. | Use production_grouped_metrics_complete.json, not historical current_csv_holdout optimization reports as final evidence. |
| 14. Reliability/confidence | Fixed downstream Bayesian/renal gates. Invalid/partial/low-average-confidence/nonfinite-confidence scans cannot produce posterior or reliable renal readings. New scans persist all ten analyte confidences; any below 0.45 or incomplete stored map fails the downstream gate. Expired/damaged/out-of-time/unsupported tests do not produce posterior or interpret protein/blood categories. | Legacy records have only average confidence; individual confidences cannot be reconstructed. Original production analyzer already checked every pad at 0.45 before returning accepted results. Physical strip timing identity remains a human gate. |
| 15. Synchronization | Source, tests and Markdown audit addenda updated; source policy is interpretation_gates_v1_20261003. Parameter-model IDs remain unchanged because numeric candidate models were not changed. | Not a final freeze: statistical decisions, clinical review, generated PDFs, manuscript/diagrams and final APK/manifest synchronization remain pending. |

## Fixes in this audit

1. Prevent symptom-only posterior on a failed scan. Previously the female path could use a symptom LR even with empty invalid scan rows, because only analyte strings were passed to fusion. Actual result/history-save paths now pass the complete scan so validity is checked before updates.
2. Stop ordinary calculation for two previously omitted systemic flags and existing renal prompt-safety outcomes. Retain independently evaluated safety advice even with invalid scans.
3. Prevent low-confidence or invalid scan data from being treated as reliable renal input. Store per-analyte confidence for new records and preserve it through JSON/copy operations.
4. Treat expired/damaged/unsupported/out-of-time strip readings as unusable protein/blood data. Preserve reported symptoms and explicitly confirmed repeat history; frozen renal priority still applies.
5. Display 52.2% male prior accurately without changing 97/186 arithmetic; strengthen female provisional wording.
6. Preserve recorded Bayesian result/model/version when reopening history. Recomputed follow-up guidance is explicitly identified as current guidance. This prevents future formula changes from silently rewriting the displayed historical posterior.

No source-study parameter is newly derived, replaced or tuned by these fixes. Clinical action thresholds and renal rule IDs are unchanged.

## Statistical-review questions (unresolved)

- Can broader-cohort threshold LRs legitimately be applied to residual exact-pattern branches after stronger patterns are excluded? If not, what supported construction replaces it?
- Can the derived younger-subgroup prior be combined with broader-cohort LRs for the selected local population? What calibration/evidence is required?
- Can the chosen female dipstick and symptom factors be multiplied? What dependence adjustment or alternative model is supported?

Retain values only as candidate research parameters until an evidence-based decision is recorded. Disclosure is necessary but does not validate the construction. Review the complete female hierarchy as well as the product of the two groups.

Principal male source: [den Heijer et al., 2012, Tables 2–3](https://pmc.ncbi.nlm.nih.gov/articles/PMC3481519/). Published threshold-level evidence is distinct from URITECT's ordered residual-branch design. Female combined-model assumption is explicitly recorded in URITECT_Bayesian_UTI_Scoring_System_v1.1.md.

## Parameter/branch crosswalk

| Validation form parameter | Meaning | Sex-specific specification branch |
| --- | --- | --- |
| M01 | Male starting prior | No branch ID |
| M02 | Both positive LR 5.14 | M1 |
| M03 | Nitrite threshold LR 4.87 | M2 |
| M04 | LE threshold LR 1.65 | M3 |
| M05 | Both negative LR 0.35 | M4 |
| No form LR parameter | Missing/unreliable/unmatched, no calculation | M5 |

## Files to read

- URITECT_UTI_Eligibility_Authority.md — exact intended-population contract and executable authority.
- URITECT_Sex_Specific_Bayesian_UTI_Specification_v1.2.md — male derivation, hierarchy, source limitations and audit addendum.
- URITECT_Bayesian_UTI_Scoring_System_v1.1.md — female mapping and formula assumptions; header model ID corrected to match current female model.
- URITECT_Bayesian_Parameter_Validation_Form_v1.3.md — medtech content review and statistical boundary addendum.
- MANUSCRIPT_FINAL_REVISION_GUIDE.md — both pathways now appear in scope; displayed posterior is no longer incorrectly called audit-only.
- uritect_app/test/methodology_audit_test.dart — edge-case regression matrix.
- uritect_app/test/bayesian_workflow_ui_test.dart — UI wording/precision/history snapshot checks.
- output/device_pilot/2026-10-03/SESSION.md — phone session and retake confirmation.

## Verification

Final full-suite and static-analysis results will be recorded below. Generated form/spec PDFs were not regenerated during this audit; use edited Markdown plus this audit until the review packet is deliberately synchronized. Do not circulate those old PDFs as containing the new addenda.

- Final flutter test --no-pub: **69 tests passed** (includes retake regression, 11 methodology audit tests, and saved-history UI test). Full log: output/device_pilot/2026-10-03/methodology_tests.log.
- Final flutter analyze --no-pub: **No issues found**.
- Reviewed the updated synthetic phone-width golden; test-font rendering differs from the installed device, so no new device visual acceptance is claimed.
- Numeric prior/LR source lines compared with HEAD and confirmed unchanged. No visual model asset modification.
- Installed APK remains 1.4.0+6 retake-only; rebuilding/installing the audited source and repeating phone workflow tests remain outstanding.

## Phone continuation

Audit-safeguards pilot 1.4.0+7 was subsequently built and installed on the RMX3933 over wireless ADB. Package version and visible home screen were verified. This supersedes the earlier build-6 installation status above; methodology workflow acceptance remains pending. Physical-device inspection also revealed a recent-history layout defect with long clinical-action text; a layout-only correction places that text beneath the date/time within the available width.

Pilot 1.4.0+8 subsequently installed with the history layout repair. Clean static analysis, successful release build, device version and home layout verified; see pilot8_launch.png and PILOT_BUILD_1.4.0+8.json. Invalid-image, eligibility and safety workflow tests remain pending.
