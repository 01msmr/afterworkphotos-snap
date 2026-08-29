# afterworkphotos-snap — design

Date: 2026-08-29. Status: **designed, nothing built.** The repo is empty; this
document is the contract the app and the endpoint keep with each other and
with `scripts/ingest.sh` in the photos repo.

## What this is

A personal iOS camera app and the small endpoint it talks to. One square
photo at a time: framed on the phone, saved to the photo library as a
favorite, and sent to `snap.afterworkphotos.com`, which hands it to GitHub.
From `inbox/` onwards the existing ingest in the photos repo takes over
unchanged.

It merges two half-plans that never met — a capture app that only saved
locally (`~/Downloads/PLAN.md`, `CLAUDE.md`, `SnapCapture.swift`) and an
upload path with no capture side. The capture pipeline was identical in both;
only the sink differed.

## The flow

```
iPhone app ──HTTPS POST──▶ snap.afterworkphotos.com/upload.php ──GitHub API──▶ afterworkphotos/inbox/
 square JPEG + app secret     holds the fine-grained PAT           ingest.yml runs, site live
        │
        └──▶ photo library, favorited (the only surviving full-size original)
```

The phone never carries a GitHub token. It carries one shared secret that can
do exactly one thing: add a photo. Revoking the app means changing one value
on the server.

## What this replaces

- **The Shortcut on the phone.** Today it PUTs into `inbox/` through the GitHub
  contents API, which means a GitHub key with broad rights sits on the phone
  (`.github/workflows/ingest.yml` states this). It goes.
- **`upload.php` in the photos repo.** It writes into `img/` and rewrites
  `const PHOTO_COUNT` in `res/main.js` — a mechanism that predates
  `photos.json`. It goes, together with its `secret.php`.

Both removals happen in the photos repo, not here, and only once this side
works end to end.

## Decisions

| Decision | Rationale | Discarded alternative |
|---|---|---|
| Save to library **and** send, on one confirm | `img originals/` is gitignored and dies with the runner — the library copy is the only permanent full-size original | Send only (nothing survives but the 1000 px stripped derivative); save only (defers the whole publication half) |
| Send failure keeps the photo on the review screen with a retry | The shot is already safe in the library; dismissing is then an explicit choice, not a silent loss | A queue or outbox — hidden state for a one-photo-at-a-time app |
| An already-present photo counts as success | A send that times out but worked would otherwise be sent twice on retry | Relying on `ingest.sh`'s duplicate drop — a safety net doing work the app should not create |
| Filename from EXIF `DateTimeOriginal`, not the clock at send time | Makes retry idempotent: the same photo PUTs the same path | Clock at send — a retry writes a second file under a different name |
| GPS written **during** the crop's single encode | A second `CGImageDestination` pass re-encodes the JPEG: two lossy generations for a metadata write | Stamping afterwards; `CGImageDestinationCopyImageSource` (lossless but pointless — the location is always known at crop time) |
| No fix → shoot anyway, mark it on the review screen | The shot matters more than the tag; you learn before you send, not on the site | Blocking capture; blocking only the send (a shot indoors could never be published); using a stale cached fix (wrong town) |
| Secret from a gitignored `Secrets.xcconfig`, seeded into the Keychain on first launch | No UI, no typing; rotating is a local file edit plus the rebuild you do anyway to install | One-time paste (the settings screen the app is not meant to have); hand-seeded Keychain (awkward setup) |
| Endpoint in **this** repo, on its own subdomain | Endpoint, app and description page are one thing; the photos repo stays about photos | Beside `scripts/` in the photos repo, as first sketched |
| PHP endpoint, deployed by commit | `snap.afterworkphotos.com` already pulls this repo the way `afterworkphotos.com` pulls the photos repo | Anything needing a build step or a second host |

## The app

### One screen

Full black. A square photo area with equal side margins, high on the screen.
Title `afterworksnap` right-aligned directly beneath it. Nothing else but
controls — no card, no rounded container, no caption, no date, no watermark.
Vertical only, identical on iPhone and iPad.

- **Live**: the whole area below the square is tappable to capture.
- **Review**: the captured square shown in place; discard on the left, green
  confirm on the right. When the capture carries no location, a small
  `no place` mark sits with the controls.
- **Sending**: a thin progress line; controls disabled.
- **After success**: back to live with a brief confirmation.
- **After a failed send**: stays on review. A plain sentence naming what
  happened, and the confirm becomes a retry. The photo is already in the
  library; discarding from here is an explicit choice to let the publication
  go.

### Capture

Unchanged from `~/Downloads/PLAN.md`, and these are decided:

- JPEG out, never HEIC.
- `photoQualityPrioritization` and `maxPhotoQualityPrioritization` both
  `.quality` — this is what engages Deep Fusion and extended low-light
  multi-frame capture. Sharpness over shutter speed, always.
- `isFastCapturePrioritizationEnabled` off.
- Flash off, deferred delivery off, depth and mattes off.
- Centre crop in raw pixel space; the orientation tag is copied, never
  rewritten. A centred square is invariant under 90° rotation, so there is no
  need to resolve orientation first.
- Image data stays `Data` end to end. A `UIImage` round-trip destroys EXIF,
  GPS and the capture date, which is the whole point.

### Location

AVFoundation does **not** embed GPS in a captured photo — Camera.app injects
it, and neither half-plan did. Without this every photo arrives placeless and
`photos.json` gets `"place": null`.

`CLLocationManager` runs while the viewfinder is live (when-in-use
authorization, `NSLocationWhenInUseUsageDescription` in Info.plist). At
capture the most recent fix is used if it is **usable**: age ≤ 60 s and
`horizontalAccuracy` in `0 < a ≤ 100` m. Otherwise the photo is written
without GPS and the review screen shows the `no place` mark.

Written keys: `GPSLatitude`, `GPSLatitudeRef`, `GPSLongitude`,
`GPSLongitudeRef` — decimal degrees positive, with `N`/`S`/`E`/`W` refs;
ImageIO converts them to the EXIF rational triples itself. Altitude and GPS
timestamp are deliberately **not** written: they serve neither the site's
place lookup nor the archive, and this is a decision, not an oversight.

### The secret

`Secrets.xcconfig` (gitignored) carries `UPLOAD_SECRET`, which reaches
Info.plist at build time. On first launch it is written to the Keychain
(`kSecClassGenericPassword`, service `co.msmr.afterworksnap`, accessibility
`kSecAttrAccessibleAfterFirstUnlock`) and the send path reads it only from
there; a later build with a different value overwrites it.

Honest limit: the secret is also in the app bundle, so the Keychain is not a
secrecy gain over reading Info.plist directly — it is the single read path for
the send. What the design does buy is that the phone holds a one-purpose
password rather than a GitHub key.

## SnapCore — the tested part

A local SwiftPM package importing **only** Foundation, CoreGraphics, ImageIO
and UniformTypeIdentifiers. Never AVFoundation, Photos, CoreLocation, SwiftUI
or UIKit — adding one breaks host testing and is a design error, not a
convenience. `swift test` runs in seconds with no simulator.

Five pure units:

**`GPSDictionary.make(latitude:longitude:)`** → `[CFString: Any]`
Values, not a `CLLocation` — CoreLocation never crosses this boundary. Sign
handling and the refs live here because this is the piece most likely to be
silently wrong.

**`SquareCrop.centered(in:gps:)`** → `Data`
`gps` defaults to nil, so `PLAN.md` steps 3 and 4 stand verbatim. Centre-crop
via `CGImageSource`/`CGImageDestination`, carrying EXIF/TIFF/GPS across,
`PixelWidth`/`PixelHeight` updated, quality 0.95, always JPEG out. The GPS
dictionary merges into the same properties dictionary — one decode, one
encode.

Acceptance: 4032×3024 → 3024×3024; 3024×4032 → 3024×3024; 3000×3000
unchanged; garbage `Data` throws `decodeFailed`; EXIF/TIFF/GPS present with
the same values; orientation tag byte-identical; output always JPEG whatever
came in; with `gps` supplied, the coordinates read back within rounding.

**`Filename.from(jpeg:)`** → `String`
`DateTimeOriginal` → `yyyyMMdd-HHmmss.jpg`. Throws when there is none rather
than falling back to the clock — a fallback would reintroduce the duplicate
this decision exists to prevent, in a case AVFoundation cannot produce.

**`LocationFreshness.isUsable(age:accuracy:)`** → `Bool`
The rule above, as a predicate over two doubles, with the thresholds as named
constants. It decides whether the `no place` mark appears, so it is tested,
not buried in a delegate.

**`UploadRequest.build(jpeg:secret:filename:endpoint:)`** → `URLRequest`
POST, `Authorization: Bearer <secret>`, `Content-Type: image/jpeg`,
`X-Filename: <name>`, the JPEG as the body.

## The app target — untested by design

`SnapSession` (AVFoundation, as drafted in `~/Downloads/SnapCapture.swift`),
`PhotoSaver` (`PHAssetCreationRequest` + `isFavorite = true`, `.readWrite`
authorization — add-only does not reliably permit setting the flag),
`LocationSource` (CoreLocation → plain doubles), `Uploader` (one
`URLSession.data(for:)` call), Keychain access, and the SwiftUI view.

Do not mock Apple frameworks. A test against a mocked `AVCapturePhotoOutput`
tests the mock. This layer stays thin enough not to need tests and is checked
on the device.

Confirm runs the sinks in order: save to the library first, then send. A save
failure stops there and reports; the send is only attempted on a saved photo.

## The endpoint

`snap.afterworkphotos.com/upload.php`. One file, no listing, no delete, no
browsing.

```
POST /upload.php
Authorization: Bearer <app secret>
Content-Type: image/jpeg
X-Filename: 20260829-184233.jpg
<raw JPEG body>
```

In order:

1. HTTPS, `POST` — anything else refused.
2. Secret compared with `hash_equals`; the server's copy lives in
   `snap-secret.php` (gitignored) alongside the GitHub PAT.
3. Body must start `FF D8 FF` and be ≤ 12 MB.
4. `X-Filename` must match `^\d{8}-\d{6}\.jpg$` — the endpoint never trusts a
   name it is given beyond that shape.
5. `PUT /repos/01msmr/afterworkphotos/contents/inbox/<name>` with the
   base64 body, on `main`. The PAT is fine-grained, that repo only, Contents:
   read and write.

Answers, as plain text:

| | |
|---|---|
| `201` | created |
| `200` | already there — GitHub answered 422 because the path exists |
| `400` | not a JPEG, no body, or a bad filename |
| `401` | wrong secret |
| `405` | not a POST, or not HTTPS |
| `413` | over 12 MB |
| `502` | GitHub refused or was unreachable |

The app treats `200` and `201` as success and shows every other answer's text
on the review screen.

A `.user.ini` in this repo's root sets `post_max_size` and
`upload_max_filesize` to `20M`, as the photos repo's does — PHP's limit
applies to the raw body, and the endpoint's own 12 MB check must be the one
that rejects, not the server's.

## The contract with `scripts/ingest.sh`

What the ingest expects of what arrives, and what this design guarantees:

- **GPS as EXIF rationals.** `gps_of_photo()` reads
  `%[EXIF:GPSLatitude]` etc. via ImageMagick `identify` and parses
  comma-separated `n/d` components, dividing each by successive powers of 60.
  ImageIO writes that shape from decimal degrees. The Swift test can only
  prove the values round-trip through ImageIO — that `identify` reads them is
  proved once, by hand, on the Mac (which has Homebrew ImageMagick).
- **`DateTimeOriginal` present.** It drives the naming
  (`awp-YYYY-MM-DD-NN`), the ordering, and the duplicate check. AVFoundation
  writes it; `Filename.from(jpeg:)` fails loudly if it is ever absent.
- **Already square.** `ingest.sh` crops to a square and says a no-op is
  expected; an already-square arrival is moved to the originals untouched.
- **Duplicates.** An arrival whose date taken matches an existing photo to the
  second is dropped. This backs up the idempotent filename; it does not
  replace it.
- **GPS is read once.** `img originals/` is gitignored, so a photo that
  arrives on the runner keeps no original beyond that run — the place is
  resolved on that first ingest or never. This is why the library copy
  matters.

Nothing in the photos repo changes for this to work.

## The description page

`index.html` at `snap.afterworkphotos.com`. Very short: a screenshot of the
app, a few lines saying what it is — a personal camera, square photos, not on
the App Store — and a link to `afterworkphotos.com`. No install links, no
feature list.

The screenshot can only exist once the app runs on the phone, so the page ships
with the text and the link first and gains the image at that step.

## Repo layout

```
AfterworkSnap.xcodeproj
AfterworkSnap/               buildable folder, thin app target
  Secrets.xcconfig           gitignored
Packages/SnapCore/           pure logic — the only place with tests
upload.php                   the endpoint
snap-secret.php              gitignored — app secret + GitHub PAT
.user.ini                    20M
index.html                   the description page
docs/superpowers/specs/
CLAUDE.md
.gitignore                   .DS_Store, xcuserdata/, DerivedData/, .build/,
                             Secrets.xcconfig, snap-secret.php
```

Do not edit `project.pbxproj`. New app files land in the buildable folder and
are picked up automatically; if something seems to need a pbxproj edit, stop
and ask. No dependencies — there is no reason for one here.

## How it is checked

- `cd Packages/SnapCore && swift test` — the five units. Red, green, commit,
  each step. Never `xcodebuild` or a simulator to check logic: if something
  can only be verified that way, it belongs in the app target and gets no
  tests.
- Fixtures are synthesised in memory — a JPEG at a given pixel size with known
  EXIF, TIFF and GPS dictionaries and a given orientation tag. No bundled
  asset files.
- Once, by hand on the Mac: `identify -format '%[EXIF:GPSLatitude]'` on a
  fixture the app's own code produced, to prove the ingest's parser reads it.
- Once, on the phone: take a shot outdoors, confirm, and watch it reach the
  library favorited with the right date, and the site with the right place.

## Open

- **Signing**: free Apple ID (7-day expiry, re-run ⌘R) or the paid Developer
  Program (99 €/yr, 1-year profile). Everything else is identical.
- **Deployment target**: iOS 18.0 assumed.
- **Bundle id**: `co.msmr.afterworksnap` assumed.

## Known limits

- **Night mode is not available to third-party apps.** There is no public API.
  `isLowLightBoostSupported` returns false regardless of configuration, and
  `AVCaptureExposureModeContinuousAutoExposure` clamps exposure to about
  1/30 s whatever `activeMaxExposureDuration` says. `.quality` is the
  strongest lever available and does engage multi-frame fusion, but night
  shots will not match Camera.app. Matching it would mean custom exposure
  control plus hand-rolled frame alignment and stacking — a project in itself.
  Judge it against real night shots before deciding it matters.
- Smart HDR has no public opt-out either; with `.quality` that is wanted
  rather than fought.
- Screen layout is derived from screenshots of the site; margins and type
  sizes are approximations and need one pass on the device.

## Not in scope

No settings screen, no gallery, no filters, no captions, no numbering, no
zoom, no front camera, no video, no queue or outbox, no retry logic beyond the
button. The endpoint gains no listing, no delete, no second route.
