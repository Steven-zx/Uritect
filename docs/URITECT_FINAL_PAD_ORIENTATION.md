# Final URITECT pad orientation

Confirmed 2026-10-11. The project owner states that the corrected physical pad order shown in CORRECTED_PAD_IDENTIFICATION.png is final and MedTech verified. This records that confirmation without inventing a reviewer name or a signed approval document.

The fixed physical order from **tip toward handle** is:

**LEU ? NIT ? URO ? PRO ? pH ? BLD ? SG ? KET ? BIL ? GLU**

- Handle below: LEU is topmost; GLU is the lowest pad next to the handle.
- Handle above: GLU is topmost; LEU is the lowest pad at the tip.
- Camera captures and gallery imports share the same analyzer. The analyzer normalizes rotations so the preview and classifier input have tip above handle. Pad coordinates, image and labels move together.
- All ten physical assignments follow this contract. Uncertain handle direction is rejected; color or classifier confidence must not decide which analyte a pad represents.
- Classify each physical pad with its own analyte model. Reversing already-classified numeric results is not a valid correction.

The machine-readable contract is URITECT_FINAL_PAD_ORDER.json. Run `python -m unittest pipeline.test_final_pad_order` to check the app analyzer, camera guide, Python geometry/schema, and bundled model against it. Physical-photo rotation tests additionally check that LEU and GLU boxes land on the observed endpoint pads.

The installed 1.5.8+25 build already implements this order, so this confirmation does not require changing or rebuilding its frozen source or APK. It verifies pad order, not classifier accuracy, reaction timing, or Bayesian calibration. Those performance limitations remain as documented in the incident report.
