# URITECT Proposed Loading Screen

## Purpose

This folder documents a proposed in-app loading/splash screen inspired by the
provided design reference. It is a planning package only. No file in
`uritect_app/lib`, no existing asset, and no application behavior has been
changed by creating this folder.

The proposed screen replaces the current static landing screen with a short,
professional launch experience before the user reaches the URITECT dashboard.
It should communicate three things immediately:

1. This is the URITECT application.
2. The app is preparing its offline workflow.
3. The user does not need to make a choice while it loads.

## Proposed User Flow

```text
Android launches app
        |
        v
Native Android launch background (instant; no blank white flash)
        |
        v
URITECT in-app loading screen (about 2.2 seconds)
        |
        v
Fade into RootPage / main dashboard
```

The loading screen is a visual startup experience. It must not claim that a
medical analysis is occurring, and it must not show a health result.

## Visual Direction

### Layout

- Full-height vertical aqua/teal-to-white gradient.
- URITECT logo centered slightly above the visual midpoint.
- Four scanner-style corner brackets surrounding the logo.
- Small, quiet loading indicator and the text `Preparing offline screening…`
  below the logo.
- Optional `Offline • On-device` supporting line in a small, low-emphasis
  style. Do not use this line if it makes the screen crowded on smaller phones.
- No `ENTER` button. The screen automatically proceeds after the short delay.

### Motion

- Fade the logo and scanner frame in over 450–600 ms.
- Apply a subtle 2–3% scale pulse to the scanner frame only.
- Use a short fade transition to the dashboard after 2.2 seconds.
- Do not use spinning, flashing, or rapid movement.
- Respect the device's reduced-motion/accessibility setting when implementing:
  show the completed static layout and use only the final transition.

## Theme Palette

The palette is based on the supplied reference image and should be used
consistently rather than sampling arbitrary colors during implementation.

| Token | Hex | Intended use |
| --- | --- | --- |
| `brandTealDark` | `#0B6F8D` | Scanner corners, wordmark accents, accessible dark text |
| `brandTeal` | `#158EAB` | Primary brand color, progress indicator |
| `gradientTop` | `#22A9BF` | Upper background gradient |
| `gradientMid` | `#76DED5` | Mid-background aqua transition |
| `gradientLower` | `#DDF7F5` | Lower background transition |
| `gradientBottom` | `#F7FCFC` | Near-white lower background |
| `surfaceWhite` | `#FFFFFF` | Optional logo halo/highlight |
| `inkDark` | `#123D4A` | Accessibility-safe text on light background |
| `mutedInk` | `#47717B` | Supporting text only |
| `shadowTeal` | `#075A72` | Very low-opacity logo/frame shadow |

Use `color_theme.json` in this folder as the copyable source of these values.

## Existing Project References

The future implementation should reuse the existing assets and navigation
structure rather than duplicate branding:

| Current resource | Proposed future use |
| --- | --- |
| `uritect_app/assets/photos/logo.png` | Main centered logo |
| `uritect_app/lib/main.dart` | Temporarily make the proposed splash page the `home` widget |
| `uritect_app/lib/pages/landing_page.dart` | Replace, retire, or keep as a separate welcome page only after team approval |
| `uritect_app/lib/pages/root_page.dart` | Destination after the loading screen |

## Implementation Process for a Future Development Session

### 1. Confirm the desired behavior

Before modifying the app, decide one item as a group:

- **Recommended:** show the loading screen every time the app launches, then
  automatically open the dashboard.
- Alternative: show it only on the first launch and retain a separate manual
  welcome page thereafter.

For the reference design, use the recommended automatic option.

### 2. Add the screen as a new page

Create `uritect_app/lib/pages/app_splash_page.dart` based on
`splash_screen_reference.dart.txt` in this folder. The reference is deliberately
stored as `.txt` so it cannot be compiled or affect the current app.

The page should:

- be a `StatefulWidget` because it manages its timed transition;
- use `SafeArea` and scalable layout constraints;
- use `Image.asset('assets/photos/logo.png')`;
- draw the scanner corner brackets with `CustomPainter` or four simple
  positioned widgets;
- navigate with `Navigator.pushReplacement` to `const RootPage()`;
- have a mounted check before navigation;
- avoid any network call, analytics call, health calculation, or database
  mutation.

### 3. Update the launch route only after review

In `uritect_app/lib/main.dart`, replace:

```dart
home: const LandingPage(),
```

with:

```dart
home: const AppSplashPage(),
```

This is the only required routing change. It should be made only when the team
approves the design.

### 4. Prevent the native white flash

An in-app splash page appears only after Flutter starts. To make the first
frame match, set the Android launch background to `gradientTop` or the closest
solid teal color. A native Android launch screen cannot reliably render the
full Flutter gradient or animation, so use a clean solid brand-teal background
with the app icon.

Do not add `flutter_native_splash` unless the team explicitly wants native
logo customization. The in-app page can be implemented with Flutter alone.

### 5. Test on actual devices

Test at minimum on:

- Samsung Galaxy A23 (the currently connected project test phone);
- one smaller Android phone, if available;
- one taller/modern Android phone, if available.

Verify portrait layout, 2.2-second transition, back-button behavior, text
legibility, no distorted logo, and no white or black flash between launch
states.

## Acceptance Checklist

- [ ] The logo is sharp and keeps its aspect ratio.
- [ ] Scanner corners frame the logo without touching or covering it.
- [ ] The full screen has no visible banding or abrupt gradient edges.
- [ ] The screen transitions automatically to the dashboard.
- [ ] The transition works while offline.
- [ ] The loading screen does not suggest a medical diagnosis or analysis.
- [ ] The user cannot remain stuck on the page if the animation is disabled.
- [ ] The back button does not navigate to a blank/duplicate launch screen.
- [ ] Text meets readable contrast against its local background.
- [ ] The design looks correct on the Samsung Galaxy A23 and at least one
  additional Android device.

## Important Product Boundary

This is a branding and navigation screen only. It must not imply that URITECT
is diagnosing a condition, loading patient data, uploading an image, or
contacting a server. The app remains offline and on-device.
