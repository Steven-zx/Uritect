# Copilot Instructions for uritect_app

## Project Overview
- **Framework:** Flutter (Dart)
- **Purpose:** Mobile application starter template
- **Structure:** Standard Flutter layout with platform-specific folders (android/, ios/, linux/, macos/, windows/, web/), main app code in lib/, and tests in test/.

## Key Files & Directories
- `lib/main.dart`: Main entry point and root widget (`MyApp`).
- `test/widget_test.dart`: Example widget test for counter increment.
- `pubspec.yaml`: Project dependencies and Flutter configuration.
- `analysis_options.yaml`: Linting rules (inherits from `flutter_lints`).

## Build & Run
- **Build/Run:** Use standard Flutter commands:
  - `flutter run` (runs app on connected device/emulator)
  - `flutter build <platform>` (builds for android, ios, web, etc.)
- **Hot Reload:** Supported via IDE or `r` in terminal during `flutter run`.

## Testing
- **Run all tests:** `flutter test`
- **Widget tests:** Place in `test/` directory. See `test/widget_test.dart` for example.

## Linting & Analysis
- **Lint rules:** Managed in `analysis_options.yaml` (inherits from `flutter_lints`).
- **Analyze code:** `flutter analyze`

## Project Conventions
- **State Management:** Default Flutter setState pattern (no external state management used).
- **UI:** Uses Material Design via `MaterialApp` and `ThemeData`.
- **Assets:** Add to `pubspec.yaml` under `flutter/assets`.
- **Dependencies:** Add to `pubspec.yaml` under `dependencies` or `dev_dependencies`.

## Platform Integration
- **Android/iOS:** Native code and configuration in `android/` and `ios/` folders.
- **Web/Desktop:** Platform-specific code in respective folders (web/, linux/, macos/, windows/).

## Patterns & Practices
- **Widget Structure:** Root widget is `MyApp`, home is `MyHomePage` (stateful, counter example).
- **Testing Pattern:** Use `WidgetTester` for widget tests.
- **No custom architectural patterns** (e.g., BLoC, Provider) present by default.

## How to Extend
- Add new screens/widgets in `lib/`.
- Add tests in `test/`.
- Update dependencies in `pubspec.yaml`.

## References
- [Flutter Documentation](https://docs.flutter.dev/)
- [Flutter Testing](https://docs.flutter.dev/testing)

---
If any conventions or workflows are unclear or missing, please provide feedback to improve these instructions.
