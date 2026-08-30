# afterworkphotos-snap

A personal iOS camera for [afterworkphotos.com](https://afterworkphotos.com), and the endpoint it sends to.

One screen drawn as a camera back: the site's print as the viewfinder, a red shutter (or say “snap”), a small LCD with name · place · date, a drum to pick one of six AI-suggested names, and two slides — retake, post. Posting writes one square JPEG — EXIF, GPS, the chosen name and the place inside it — to the photo library as a favourite and to `snap.afterworkphotos.com/upload.php`, which puts it into the photos repo's `inbox/`. The ingest there does the rest and the photo is live. English and German, light and dark, iPhone and iPad. Not on the App Store.

- `docs/superpowers/specs/2026-08-29-snap-design.md` — the pipeline and the contract with the ingest
- `docs/superpowers/specs/2026-08-30-camera-back-design.md` — the camera back, as built
- `docs/superpowers/plans/2026-08-29-snap.md` — how it was built
- `Packages/SnapCore` — the tested part: `cd Packages/SnapCore && swift test`
- `AfterworkSnap/` — the app; open `AfterworkSnap.xcodeproj` with Xcode-beta 27, run on the phone with ⌘R
- `upload.php` — the endpoint; `snap.afterworkphotos.com` pulls `main`
- `index.html` — the page at snap.afterworkphotos.com

Secrets, both gitignored, never committed: `AfterworkSnap/Secrets.xcconfig` (the app secret and the Anthropic key, built into the app) and `snap-secret.php` (the app secret plus the GitHub token, copied to the server by hand). The GitHub token expires; when uploads answer 401, make a new one.
