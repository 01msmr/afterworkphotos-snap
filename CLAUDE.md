# afterworksnap

Personal iOS camera app. Square photos, saved to the photo library as
favorites and sent to snap.afterworkphotos.com, which puts them into the
photos repo's inbox/. Never shipped to the App Store. Design and contract:
docs/superpowers/specs/2026-08-29-snap-design.md.

## Layout

AfterworkSnap/        app target — buildable folder, framework code only
Packages/SnapCore/    pure logic — the only place with tests
upload.php            the endpoint; deployed by commit, the server pulls main

## Working method

TDD, strictly. Write the failing test first, run it, watch it fail, then make
it pass. YAGNI: build only what the current step needs.

```bash
cd Packages/SnapCore && swift test
```

That is the loop. Never run `xcodebuild` or boot a simulator to check logic —
if something can only be verified that way, it belongs in the app target and
does not get tests.

Commit after each green step. Small commits, present tense subject lines.

## Rules

- `SnapCore` imports only Foundation, CoreGraphics, ImageIO and
  UniformTypeIdentifiers. Never AVFoundation, Photos, SwiftUI or UIKit —
  adding one of those breaks host testing and is a design error, not a
  convenience.
- Do not mock Apple frameworks. A test against a mocked `AVCapturePhotoOutput`
  tests the mock.
- Do not edit `project.pbxproj`. New app files land in the buildable folder and
  are picked up automatically. If something seems to need a pbxproj edit, stop
  and ask.
- Do not add dependencies. There is no reason for one in this project.
- Image data stays as `Data` end to end. A `UIImage` round-trip destroys EXIF,
  GPS and the capture date, which is the whole point of the app.
- Never commit `AfterworkSnap/Secrets.xcconfig` or `snap-secret.php`.

## Photo pipeline invariants

These are decided. Do not "improve" them without being asked.

- JPEG out, never HEIC
- `photoQualityPrioritization` and `maxPhotoQualityPrioritization` both
  `.quality` — sharpness over shutter speed, always
- `isFastCapturePrioritizationEnabled` off
- flash always off, deferred delivery off, depth and mattes off
- centre crop in raw pixel space; the orientation tag is copied, never rewritten
- saved with `PHAssetCreationRequest` + `isFavorite = true`, `.readWrite` auth
- no albums, shared or otherwise
- multi-cam where supported: the front camera runs preview-only into the
  shutter's face (smallest format); the back keeps a multi-cam-capable
  format with the photo ceiling raised by hand — never at the cost of the
  rules above

## UI invariants

Dark only — pinned at the root; the light-mode branches stay in the code,
unreachable. The camera back: leather body, the matte square print high on
the screen (no title band), LCD beneath it, the chrome release centred
below with the drum panel beside it, retake · `Snap` logo · post at the
bottom. Vertical only, iPhone and iPad at the same point sizes; home
screen name `Snap` (Info.plist AND the pbxproj build setting — the
setting overrides the plist).

The release is measured in millimetres, physical per device (`Metrics.mm`,
6 pt/mm iPhone, 5.2 pt/mm iPad): flat satin face, 1 mm edge roundover
(same material, no rim), 0.2 mm black gap, 0.5 mm leather roll-in, 1.5 mm
travel, shot on release, front camera mirrored in the face. Never morphs.
Ratchet ticks are by LENGTH, pitch by speed. Design of record:
docs/superpowers/specs/2026-08-31-chrome-release-design.md.
