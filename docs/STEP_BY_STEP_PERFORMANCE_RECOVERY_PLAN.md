# Uritect Performance Recovery Plan (Student-Friendly)

## 1) What your current metrics mean

- Accuracy: How many predictions are exactly correct out of all predictions.
- F1-macro: Average F1 across classes, giving equal importance to rare and common classes.
- Strict multiclass: Predicted level must exactly match the true level (hardest metric).
- Adjacent accuracy: Predicted level can be off by one neighboring level and still counted as acceptable.
- Coarse normal-vs-abnormal: Only checks if prediction is normal or abnormal (much easier than strict multiclass).

Current baseline (strict multiclass):
- Overall accuracy: 0.232
- Overall F1-macro: 0.174

Interpretation:
- The system is working technically, but exact level separation is still weak.

## 2) Why performance is currently low

Main reasons:
1. Too few independent examples per analyte level.
2. Many classes are visually similar (neighboring shades are hard to separate).
3. Synthetic-only ground truth does not fully represent real capture variability.
4. Current feature space (mostly HSV distance) is too simple for fine-grained level separation.
5. Per-analyte models were tested, but data is still too limited for them to generalize.
6. Hard cases (e.g., high Glucose/Ketone bins) were not yet mined and retrained in a focused loop.

## 3) What to do now (step-by-step with expected uplift)

Important: These uplifts are realistic ranges, not guarantees.

### Step 0 — Lock evaluation protocol (do this first)
Actions:
- Keep one frozen holdout set unchanged.
- Keep one pinned baseline report file for comparison.
- Report only Accuracy and F1-macro for Phase 1 summary.

Expected uplift:
- Accuracy: no direct lift (0.232 stays 0.232)
- F1-macro: no direct lift (0.174 stays 0.174)
- Benefit: prevents accidental metric inflation and gives honest progress tracking.

### Step 1 — Data audit and class map
Actions:
- For every analyte-level, compute train count and holdout count.
- Flag all levels with <40 train examples as high risk.
- Build a priority list from confusion matrix hotspots.

Expected uplift after retraining with only cleaned/organized splits:
- Accuracy: +0.01 to +0.03
- F1-macro: +0.01 to +0.03

### Step 2 — Label reliability pass (dual review for hard bins)
Actions:
- Dual-label confusing neighboring levels.
- Add adjudication rule sheet for disagreements.
- Remove uncertain labels from training (or mark low-confidence and down-weight later).

Expected uplift:
- Accuracy: +0.02 to +0.05
- F1-macro: +0.03 to +0.06

### Step 3 — Capture protocol enforcement (calibration rigor)
Actions:
- Standardize strip read timing.
- Require white reference visibility/quality checks.
- Reject blurred/glare captures.
- Enforce per-session normalization before inference.

Expected uplift:
- Accuracy: +0.02 to +0.04
- F1-macro: +0.02 to +0.05

### Step 4 — Add stronger features (before changing model family)
Actions:
- Keep HSV features, then add:
  - Lab color features,
  - hue circular statistics,
  - ratio features,
  - local contrast/texture summaries on pad ROI.
- Normalize features and run ablations (feature groups on/off).

Expected uplift:
- Accuracy: +0.03 to +0.07
- F1-macro: +0.04 to +0.08

### Step 5 — Move to per-analyte ordinal modeling
Actions:
- Train one model per analyte using ordinal-aware objective.
- Add class weighting and adjacent-level penalty.
- Keep baseline KNN as control.

Expected uplift:
- Accuracy: +0.03 to +0.08
- F1-macro: +0.04 to +0.10

### Step 6 — Confidence policy and recapture gate
Actions:
- Add thresholds for low-confidence predictions.
- Output needs recapture for uncertain cases.
- Track coverage vs strict accuracy tradeoff.

Expected uplift on accepted predictions:
- Accuracy: +0.03 to +0.08
- F1-macro: +0.03 to +0.08
- Coverage may decrease depending on thresholds.

### Step 7 — Hard-case mining loop (highest practical booster)
Actions:
- After each retrain, extract top confusion pairs.
- Collect targeted new samples for those pairs.
- Retrain and re-evaluate on frozen holdout.
- Repeat 2–3 cycles.

Expected uplift per loop:
- Accuracy: +0.02 to +0.05
- F1-macro: +0.03 to +0.06

## 4) Example cumulative trajectory (realistic)

Starting baseline:
- Accuracy: 0.232
- F1-macro: 0.174

After Step 1–3:
- Accuracy: 0.27 to 0.34
- F1-macro: 0.24 to 0.34

After Step 4–5:
- Accuracy: 0.34 to 0.49
- F1-macro: 0.32 to 0.52

After Step 6–7 (with hard-case collection loops):
- Accuracy: 0.45 to 0.62
- F1-macro: 0.42 to 0.65

Reaching 0.80+ strict multiclass overall usually requires:
- much larger balanced data,
- stronger domain coverage,
- and several disciplined data/model iterations.

## 5) What to say in defense tomorrow (simple script)

- We intentionally report strict multiclass baseline metrics for Phase 1 to avoid overclaiming.
- The current baseline validates pipeline reproducibility and identifies failure hotspots.
- We already prepared a quantified improvement roadmap with measurable checkpoints.
- Phase 2 focuses on targeted data expansion, ordinal modeling, and hard-case mining.

## 6) Immediate next checklist (24-hour realistic)

1. Present baseline scorecard honestly.
2. Present strict vs adjacent vs coarse metric distinction.
3. Show top confusion hotspots and why they happen.
4. Show this step-by-step plan with projected uplift ranges.
5. Commit to frozen holdout and no metric-protocol changes during defense.
