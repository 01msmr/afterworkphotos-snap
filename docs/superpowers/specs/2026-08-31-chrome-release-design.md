# afterworksnap — the chrome release: design

Date: 2026-08-31. Status: **built and in use** (one evening, device-driven,
each round pushed to the phone within seconds of ⌘B). Builds on
`2026-08-30-camera-back-design.md`, which stays in force except where this
document says otherwise. Visualization of record:
https://claude.ai/code/artifact/c4319e29-488c-4ff3-aa74-77511195e2ec
(interactive: the button presses, the section carries the measures).

## What changes

The red glass shutter becomes a machined satin-chrome disc with the
photographer really reflected in it; the app goes dark-only, loses its
title band, and is named `Snap` on the home screen. The button, the
sliders and the wheel get a physical language — millimetre geometry,
haptics, length-based ratchet ticks, mechanical sounds — and posting
becomes theatre: the print audibly and visibly leaves the camera.

## The release (all measures physical, `Metrics.mm`: 6 pt/mm iPhone, 5.2 pt/mm iPad)

| measure | value |
|---|---|
| disc Ø | 96 pt (15.9 mm iPhone, 18.5 mm iPad) |
| edge roundover | 1 mm — same material, drawn as a soft darkening only; **no rim, no gloss** |
| gap around the disc | 0.2 mm, pure black |
| leather roll-in | 0.5 mm — the body's radius turns *down into* the well, dark; no bright ring |
| press travel | 1.5 mm in; the shot fires on release |

Face: dead flat, satin — the **front camera's mirrored feed** blurred
`mm(1.2)`, saturation 0.75, brightness −0.05, under a faint breath of
metal. Where multi-cam is unsupported, a drawn silhouette (head,
shoulders, raised phone). The disc never morphs; `locked` only dims it.

**Touch mechanics** (`ShutterTouch`, UIKit — SwiftUI can't see the
finger): `UITouch.majorRadius` is tracked; when the contact patch falls
below 60 % of its peak the fingertip is peeling off — the disc springs
back and the release tick plays *before* touch-up, onto skin that can
still feel it. The shot itself stays on touch-up. While a finger is on
the button the voice trigger is gated (`shutterHeld`).

**Haptics** (`ShutterHaptics`, CoreHaptics; rigid-impact fallback): press
= sharp snap + its 12 ms rebound; release = lighter tick; locked = a dead
double-knock (no travel, no snap). Requires
`setAllowHapticsAndSystemSoundsDuringRecording(true)` on the audio
session — the always-on "snap" listener otherwise silences every haptic
in the app.

## The capture session

`AVCaptureMultiCamSession` where supported: the back camera keeps a
multi-cam-capable format with the photo ceiling raised by hand (multi-cam
has no `.photo` preset); the front camera runs its **smallest** multi-cam
format, preview-only, mirrored automatically, portrait rotation, wired
with explicit no-connection adds. Any front-side failure leaves the back
camera exactly as before and the button with its silhouette.

## Sounds (all in `AfterworkSnap/Sounds/`, preloaded at start off-main; playback on its own queue — `AVAudioPlayer.play()` blocks ~ms and used to hitch drags)

| name | sound | source |
|---|---|---|
| `shutter` | the shot: short "ti-k", 70 ms, noise-built, nothing glassy | synthesized |
| `tchack` | SLR mirror slap — **shelved, unloaded**, decided against | synthesized |
| `eject` | post: an inkjet pushing the printed sheet out, 1.0 s, loud from the first 50 ms (since 2026-09-22; the cardboard door slide was too harsh) | BigSoundBank #0169 "Inkjet printer", CC0 — 15.44–16.42 s, the push from its first hit (the rollers' wind-up before it cut: the sound must start on the slide's release), before the silence and the handling; 120 Hz–6 kHz, 5 ms fade in, mean −31 dB |
| `zip` | retake: the print drawn back in, 0.28 s | the old eject's door-slide recording **reversed**, 1.5×, softer |
| `thup` | the print landing (post success) — **retired 2026-09-22, shelved, unloaded**: the post ends on the sheet sound | synthesized |
| `knock` | dead double-knock (post failure) | synthesized |
| `step` + `_p0…p4` | slider ratchet, featherweight, subs-free | synthesized, 5 pitches |
| `tick` + `_p0…p4` | the drum's row tick | original, re-pitched ×5 |
| `crunch` | old retake crumple — retired, commented | kept in bundle |

Source recording: `Door Display Case Slide Open 2 - QuickSounds.com.mp3`
(user-supplied, in `~/Downloads`; the WAVs are derived and committed).
`Sounds.play(_:speed:)` picks a pre-pitched variant by normalized speed —
`AVAudioPlayer.rate` doesn't bend pitch dependably, so pitch is baked in.

**Ratchets are length-based, never time-based**: sliders tick every 9 pt
of knob travel, both directions (the step into the fire zone is silent —
the fire sound owns it); the drum ticks per row. Both rise in pitch with
drive speed (dt between ticks → 0…1 → variant).

## The post theatre

On the post slide's release: the eject sound, and the print slides out of
the viewfinder to the right (0.45 s, easeIn) revealing the live view; the
camera unfreezes after 500 ms while the upload runs on (`full` is kept
for the upload and a retry). Success: the sent sign, silent (the `thup` is retired); failure:
`knock` + the twitching error, as before.

**Tapping the `Snap` logo runs the whole post as a demo** — eject, print
out, sending pause (1.2 s), sent sign — with **nothing saved and
nothing uploaded** (`demoPost()`; needs a shot up). The old mail-whoosh
test hook is gone; the system whoosh (1001) is no longer used anywhere.

## The rest of the screen

- **Dark only**: `.preferredColorScheme(.dark)` at the root; every
  light-mode branch remains in code, unreachable.
- **No title band**: the print keeps its 56 pt top; `titleTop`,
  `titleHeight`, the red shutter colours and `Theme.title` are gone.
- **Viewfinder matte**: ground glass — white veil 0.045, saturation 0.90,
  contrast 0.94 on the square (print included).
- **Slides** are a third of a knob narrower than their natural width
  (`max(96, natural) − knob/3`), shorter throw, same 85 % threshold.
- **Home screen `Snap`**: `CFBundleDisplayName` in Info.plist **and**
  `INFOPLIST_KEY_CFBundleDisplayName` in the pbxproj — the build setting
  overrides the plist, both must agree.

## Upload (added 2026-09-22)

- **The strip**: a flat rectangle, half the screen wide, centred, 45 pt
  high, corners 8 % of that, 10 pt above the bottom row (reserved in the
  fixed stack: height-bound screens shrink the print 13 pt) —
  `Theme.yellow` at 50 %, "Upload" in
  the slides' label type, dark. It opens the system `PhotosPicker` (one
  image, `.current` encoding: the original file, EXIF and GPS intact; no
  library permission). Enabled only while the print is empty (the
  shutter's rule); dimmed to 40 % otherwise.
- **The picked photo** takes the capture's place: the print shows it, the
  date comes from its EXIF, the place from its EXIF GPS (none → `-`), the
  six names from Claude as usual. Post crops it square, writes JPEG (HEIC
  in is fine) and uploads it — **no library save**, it is already there.
- **The badge**: while a picked photo is on the print, "Upload" on 50 %
  yellow sits in its bottom-left corner — on screen only, never in the
  file; above the matte, leaving with the print on post, gone on retake.
- **Share with Snap** (the `SnapShare` extension): in Photos' share sheet,
  any number of photos, the first is taken. Its original file goes onto
  the named pasteboard `co.msmr.afterworksnap.picked` (the signing team
  is a free one — no App Groups), then the extension opens
  `afterworksnap://picked` up the responder chain (not allowed to
  extensions officially; fine off the App Store). Snap takes the photo on
  that URL or whenever it comes forward, only while the print is empty,
  and empties the pasteboard — from there it is the Upload flow.
- Multi-select is a later, separate design.

## Deploying while Xcode Run refuses the phone

iOS beta 8 (24A5430a) on the device vs Xcode 27 beta 6: Run balks, but
install works. Build with ⌘B, then:

    xcrun devicectl device install app --device 00008140-000D14640C93001C \
      ~/Library/Developer/Xcode/DerivedData/AfterworkSnap-*/Build/Products/Debug-iphoneos/AfterworkSnap.app
    xcrun devicectl device process launch --device 00008140-000D14640C93001C co.msmr.afterworksnap

(`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.)

## Open

- The mm→pt table and section live in the visualization linked above.
- (Resolved 2026-09-05: `index.html` now shows the chrome release —
  the staged `img/app-awp20.jpg` — with copy to match.)
