# Thesis Project Foundation (Working Brief)

## Proposed Title
**A Hybrid Illumination-Invariant, Multimodal Smartphone-Based Urinalysis Screening System Using Colorimetric Strip Analysis and Clinical Symptom Integration**

## Core Problem
Manual dipstick interpretation is fast but subjective, lighting-sensitive, and inconsistent in timing/reading quality. Existing smartphone urinalysis solutions improve convenience but often remain vulnerable to illumination shifts and typically ignore symptom context.

## Research Gap
1. **Illumination invariance gap** in real-world capture conditions (warm/neutral/cool lighting).
2. **Unimodal limitation** (visual-only inference without symptom-aware weighting).
3. **Rural deployment gap** (need for lightweight, offline-capable implementation on entry-level phones).

## Proposed Solution (High-Level)
A hybrid mobile screening system with:
1. **Reference-based Adaptive White Balancing (AWB)** using the strip’s unreacted white plastic as dynamic white reference.
2. **Automated strip/pad segmentation** via edge + contour-based localization and ROI slicing.
3. **Late-fusion multimodal engine** combining visual features (HSV/colorimetric) and clinical symptoms to produce **risk-stratified** outputs.

## Scope and Intended Use
- **Intended use**: clinical decision support / risk stratification screening tool.
- **Not intended**: definitive diagnostic replacement.
- **Target context**: rural health units and low-resource settings.
- **Deployment requirement**: offline-capable, on-device inference.

## Study Objectives (Operationalized)
### General
Design, implement, and evaluate an illumination-invariant image-processing + multimodal risk assessment pipeline for automated 10-parameter urinalysis on mobile devices.

### Specific
1. Build calibrated synthetic-control dataset under **2700K / 4000K / 5500K**.
2. Implement reference-based AWB (gray-world-guided correction).
3. Implement robust ROI segmentation independent of strip orientation/background noise.
4. Implement k-NN multimodal fusion of HSV features + symptoms.
5. Integrate into lightweight offline mobile app.
6. Evaluate against analyzer gold standard via accuracy, efficiency, and lighting robustness metrics.

## System Architecture (Functional)
1. **Image Preprocessing Module**
   - Input: raw camera image
   - Output: white-balanced image corrected by strip-reference matrix
2. **Segmentation Module**
   - Strip isolation, perspective correction, and 10-pad ROI extraction
3. **Multimodal Analysis Module**
   - Visual branch: HSV feature extraction and color-class mapping
   - Clinical branch: symptom flags (e.g., dysuria, flank pain, edema)
   - Fusion: weighted risk scoring for borderline/ambiguous visual readings

## Methodology Snapshot
### Phase 1 – Dataset Creation
- Use Level 1/2/3 control solutions (negative/low abnormal/high abnormal).
- Capture images across warm/neutral/cool lighting setups.

### Phase 2 – Model Development
- Train k-NN with colorimetric ground truth.
- Tune AWB to minimize cross-light color discrepancy (e.g., Delta E).

### Phase 3 – Validation
- Compare app outputs vs clinic automated analyzer on real samples (target range: 30–50).

## Evaluation Plan
1. **Diagnostic agreement**
   - Sensitivity, specificity, confusion matrix
   - Cohen’s kappa against gold standard analyzer
2. **Runtime performance**
   - Average processing latency per sample (ms)
3. **Illumination robustness**
   - Output variance across 2700K/4000K/5500K conditions
4. **Statistical testing**
   - ANOVA for lighting-condition effect on performance

## Clinical Threshold Basis (From Proposal)
- Proteinuria risk emphasis at **>=1+ (30 mg/dL)**
- UTI logic strengthened by **nitrite + leukocyte esterase** combination
- Glucosuria concern at **>=1+ (100 mg/dL)**
- Symptom-informed weighting for red flags (e.g., dysuria, edema)

## Implementation Implications for the App
1. Require camera capture guardrails (distance, focus, timer window).
2. Keep color pipeline deterministic and reproducible across devices.
3. Store local rule/version metadata for traceability of risk scoring.
4. Show explainable outputs (which pads + which symptoms increased risk).
5. Preserve offline-first workflow and lightweight model footprint.

## Current Risks to Manage Early
1. Device camera heterogeneity (sensor/ISP differences).
2. Shadow and perspective artifacts during capture.
3. Label quality and class imbalance in calibration dataset.
4. Overfitting to synthetic controls with poor real-sample generalization.
5. Clinical interpretation drift if threshold/rules are not version-controlled.

## Open Items to Finalize in Thesis + Build
1. Exact symptom-weighting formulation (rule-based vs learned weight tuning).
2. Precise target metrics (minimum acceptable kappa, sensitivity/specificity floors).
3. Human factors protocol for capture timing after dipstick immersion.
4. Ethics/privacy handling for patient metadata storage on device.
5. Reference list cleanup (one entry has missing title text).

## References Note
The proposal indicates IEEE style for references, with BLIS exception in APA where required. Keep one consistent citation map in thesis drafts to avoid numbering drift.

---
This file is the canonical engineering brief for this workspace and should be treated as the baseline for feature and experiment decisions unless superseded by adviser-approved revisions.
