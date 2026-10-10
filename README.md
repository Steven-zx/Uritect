# URITECT

Offline Android research prototype for ten-pad urine dipstick interpretation, a provisional literature-derived Bayesian UTI screening estimate, and rule-based renal follow-up.

Start with [the developer evaluation handoff](docs/URITECT_DEVELOPER_EVALUATION_HANDOFF.md). The frozen evaluation candidate is **1.5.11+28**. Clinical validation is not established; experimental classifier metrics are separate from disease-detection performance.

## Project map

| Folder | Purpose |
|---|---|
| `uritect_app/` | Flutter app, Android build configuration, offline model assets and app tests |
| `pipeline/` | Dataset processing, feature extraction, classifier evaluation and reproducibility tooling |
| `docs/` | Methodology, implementation decisions, review protocols and known limitations |
| `output/device_pilot/` | Versioned build evidence; APKs and source archives stay outside Git |

## Verify the app

From `uritect_app`:

```text
flutter pub get
flutter analyze
flutter test
```

Release signing requires the owner's private signing configuration, which is deliberately excluded from Git. Developers can use `flutter build apk --debug` for local evaluation. Use the frozen signed APK for the planned pilot so all evaluators test the same version.

Python evaluation uses the existing local research dataset, which is excluded from Git. Dataset-dependent results are documented rather than silently regenerated from absent inputs. See the handoff for environment, commands, evidence and remaining manual checks.
