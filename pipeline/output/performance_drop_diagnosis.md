# Performance Drop Diagnosis

Baseline: `semiquant_gold_holdout_eval_restored_prior.json`\n- Acc: 0.2320\n- F1-macro: 0.1744\n- Kappa: 0.2157\n\n## Ranked by F1 delta vs baseline

1. **semiquant_gold_holdout_eval_neg_guard.json** | Acc=0.0000 (Δ -0.2320) | F1=0.0000 (Δ -0.1744) | Kappa=0.0000 (Δ -0.2157) | Coverage=0.000 (0/0)
   - Likely change: general experiment variant
2. **semiquant_gold_holdout_eval_event_centered_per_light_calibrated.json** | Acc=0.2040 (Δ -0.0280) | F1=0.0664 (Δ -0.1081) | Kappa=0.1877 (Δ -0.0279) | Coverage=1.000 (250/250)
   - Likely change: event-center strategy variant
3. **semiquant_gold_holdout_eval_edited_colorwheel.json** | Acc=0.2120 (Δ -0.0200) | F1=0.0865 (Δ -0.0879) | Kappa=0.1950 (Δ -0.0207) | Coverage=1.000 (250/250)
   - Likely change: DEV reference source switched to edited colorwheel set
4. **semiquant_gold_holdout_eval_weighted_abstain_v1.json** | Acc=0.2045 (Δ -0.0275) | F1=0.0982 (Δ -0.0762) | Kappa=0.1756 (Δ -0.0401) | Coverage=0.176 (44/250)
   - Likely change: analyte-specific HSV weighting enabled; confidence/distance abstain band enabled
5. **semiquant_gold_holdout_eval.json** | Acc=0.2080 (Δ -0.0240) | F1=0.1124 (Δ -0.0620) | Kappa=0.1914 (Δ -0.0243) | Coverage=1.000 (250/250)
   - Likely change: general experiment variant
6. **semiquant_gold_holdout_eval_event_centered_per_light.json** | Acc=0.2040 (Δ -0.0280) | F1=0.1409 (Δ -0.0335) | Kappa=0.1871 (Δ -0.0286) | Coverage=1.000 (250/250)
   - Likely change: event-center strategy variant
7. **semiquant_gold_holdout_eval_weighted_abstain_light_v1.json** | Acc=0.2297 (Δ -0.0023) | F1=0.1594 (Δ -0.0151) | Kappa=0.2129 (Δ -0.0028) | Coverage=0.592 (148/250)
   - Likely change: analyte-specific HSV weighting enabled; confidence/distance abstain band enabled
8. **semiquant_gold_holdout_eval_20260323_baseline_restored.json** | Acc=0.2320 (Δ +0.0000) | F1=0.1744 (Δ +0.0000) | Kappa=0.2157 (Δ +0.0000) | Coverage=1.000 (250/250)
   - Likely change: baseline restored reference map
9. **semiquant_gold_holdout_eval_after_adaptive_grid.json** | Acc=0.2320 (Δ +0.0000) | F1=0.1744 (Δ +0.0000) | Kappa=0.2157 (Δ +0.0000) | Coverage=1.000 (250/250)
   - Likely change: general experiment variant
10. **semiquant_gold_holdout_eval_event_centered.json** | Acc=0.2320 (Δ +0.0000) | F1=0.1744 (Δ +0.0000) | Kappa=0.2157 (Δ +0.0000) | Coverage=1.000 (250/250)
   - Likely change: event-center strategy variant
11. **semiquant_gold_holdout_eval_gridlock.json** | Acc=0.2320 (Δ +0.0000) | F1=0.1744 (Δ +0.0000) | Kappa=0.2157 (Δ +0.0000) | Coverage=1.000 (250/250)
   - Likely change: grid-locked localization experiment
12. **semiquant_gold_holdout_eval_legacy_noabstain.json** | Acc=0.2320 (Δ +0.0000) | F1=0.1744 (Δ +0.0000) | Kappa=0.2157 (Δ +0.0000) | Coverage=1.000 (250/250)
   - Likely change: confidence/distance abstain band enabled; legacy equal HSV distance weights
13. **semiquant_gold_holdout_eval_per_pad_localized.json** | Acc=0.2320 (Δ +0.0000) | F1=0.1744 (Δ +0.0000) | Kappa=0.2157 (Δ +0.0000) | Coverage=1.000 (250/250)
   - Likely change: general experiment variant
14. **semiquant_gold_holdout_eval_restored_prior.json** | Acc=0.2320 (Δ +0.0000) | F1=0.1744 (Δ +0.0000) | Kappa=0.2157 (Δ +0.0000) | Coverage=1.000 (250/250)
   - Likely change: baseline restored reference map
15. **semiquant_gold_holdout_eval_weighted_noabstain_v1.json** | Acc=0.2360 (Δ +0.0040) | F1=0.1782 (Δ +0.0038) | Kappa=0.2197 (Δ +0.0041) | Coverage=1.000 (250/250)
   - Likely change: analyte-specific HSV weighting enabled; confidence/distance abstain band enabled

## Largest drop

- File: **semiquant_gold_holdout_eval_neg_guard.json**
- ΔF1: -0.1744, ΔAcc: -0.2320, ΔKappa: -0.2157
- Likely change: general experiment variant
