# afterworkphotos-snap

A personal iOS camera for [afterworkphotos.com](https://afterworkphotos.com), and the endpoint it sends to.

One screen: a square viewfinder, tap to shoot, `discard` or `save`. Saving puts the square JPEG — EXIF and GPS intact — into the photo library as a favourite and POSTs it to `snap.afterworkphotos.com/upload.php`, which PUTs it into the photos repo's `inbox/`. The ingest there does the rest: name by date taken, town from the GPS, caption, thumbnails, live on the site. Not on the App Store.

- `docs/superpowers/specs/2026-08-29-snap-design.md` — the design and the contract with the ingest
- `docs/superpowers/plans/2026-08-29-snap.md` — how it was built
- `Packages/SnapCore` — the tested part: `cd Packages/SnapCore && swift test`
- `AfterworkSnap/` — the app; open `AfterworkSnap.xcodeproj` with Xcode-beta 27, run on the phone with ⌘R
- `upload.php` — the endpoint; `snap.afterworkphotos.com` pulls `main`
- `index.html` — the page at snap.afterworkphotos.com

Secrets, both gitignored, never committed: `AfterworkSnap/Secrets.xcconfig` (the app secret, built into the app) and `snap-secret.php` (the same secret plus the GitHub token, copied to the server by hand).
