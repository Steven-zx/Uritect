# Evidence-gap remediation — 2026-10-12

Source: `URITECT_UNRESOLVED_EVIDENCE_GAPS.pdf`, a two-page read-only review of build 1.5.11+28. It remains an unchanged historical source. The current candidate is 1.5.13+30, with the restored opening screen and per-pad timing restrictions. This response distinguishes implemented safeguards from external evidence still absent.

| PDF rank | Finding | Work completed | Evidence still required |
|---|---|---|---|
| 1 | No prospective culture-confirmed validation | Research framing and no diagnosis/calibration claims retained; outcome study requirements remain in review packet | Independent approved protocol and culture-confirmed outcomes; NOT VERIFIED - supporting evidence not located |
| 2 | Physical strip/IFU not identified | Owner's product, lot, confirmed dates and ten-pad time schedule recorded; discovered single-60-second mismatch corrected with per-pad restrictions | Manufacturer/chart/IFU, tolerances, anti-VC limits and signed physical-strip review; NOT VERIFIED - supporting evidence not located |
| 3 | Exact-build device checklist not run | Version/hash-bound current checklist and acceptance record prepared; automated evidence retained separately | Actual D01-D15 observations on two different phones; NOT VERIFIED - supporting evidence not located |
| 4 | Male residual LRs and female multiplication unresolved | Exact existing parameters preserved, pending retain/revise/withhold review form prepared; no invented replacement factors | Statistician rationale and signed decision; expert arithmetic approval alone does not calibrate a model |
| 5 | Inspected confirmation set and rare support | Corrected grouped split and exploratory limitations disclosed; failed pH/SG candidates not deployed | Independent specimen-grouped outcomes and adequate class support; deferred collection cannot be replaced by augmentation |
| 6 | Expert/physician reviews pending | Current-build packet prepared, with three MedTech content-review slots separate from usability evaluation | Signed actual MedTech, physician, statistician and usability evidence; NOT VERIFIED - supporting evidence not located |
| 7 | Manuscript/build drift | Review/manuscript guides updated; required-pad confidence wording corrected; old manifest generator's hardcoded model version removed; current evidence index and drift verifier added | Editable manuscript and diagrams, actual chapter edits and final consistency review; manuscript source NOT VERIFIED - supporting evidence not located |

## Confirmed implementation correction

The owner confirms the bottle dates as May 12, 2026 manufacture and May 11, 2028 expiry, lot `2026051201`. Their transcribed schedule is bilirubin/glucose 30 s, ketone 40 s, SG 45 s, all other pads 60 s. The manufacturer is not printed according to the owner; the reported anti-VC statement has no supplied limits.

Previously, a self-reported time of any nonnegative number could pass the current-context check even when the required UTI/renal pads needed 60 seconds. The app now requires schedule consistency for each actual required input pad. Unsupported timing blocks new ordinary estimates. Each row shows matching reported time or image-review-only status. All numerical review values and symptom-based safety guidance remain available; no label, classifier, LR, prior or clinical risk threshold changes.

A 60-second picture does not produce a correctly timed complete ten-pad result. No allowable timing window was supplied; exact reported-target comparisons are an engineering consistency check, not an invented manufacturer tolerance. No automatic sequential capture, cross-photo merge or biologically authenticated timer is claimed.

General vitamin-C interference is supported by [this multicenter study](https://pmc.ncbi.nlm.nih.gov/articles/PMC6816989/), which evaluated a different strip. It does not establish this lot's behavior. [PROBAST+AI](https://www.bmj.com/content/388/bmj-2024-082505) distinguishes quality/bias in prediction-model performance evaluation from the existence of expert content review. Neither source supplies missing local outcome evidence.

## Finalization boundary

Engineering source and a signed evaluation candidate can be frozen for supervised review. The seven external evidence requirements cannot be closed by changing their status fields. Use `pipeline/verify_current_evidence.py` to verify current source/artifact identity and list open gates. Its `--require-final` mode must refuse final acceptance while required evidence remains missing.

The device is not currently connected. No manual device-test pass or review signature is fabricated. Older installed build evidence does not transfer to this new APK. The historical PDF, old release manifests and prior APKs are preserved.
