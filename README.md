# afterworkphotos-snap

A personal iOS camera for [afterworkphotos.com](https://afterworkphotos.com), and the endpoint it sends to.

One screen drawn as a camera back, dark only: the site's print as a matte viewfinder, a satin-chrome release with the photographer really reflected in it (front camera, multi-cam) — press and it sinks 1.5 mm, the shot fires on release, or say “snap” — a small LCD with name · place · date, a drum to pick one of six AI-suggested names, and two slides — retake, post. Posting ejects the print from the viewfinder and writes one square JPEG — EXIF, GPS, the chosen name and the place inside it — to the photo library as a favourite and to `snap.afterworkphotos.com/upload.php`, which puts it into the photos repo's `inbox/`. The ingest there does the rest and the photo is live. English and German, iPhone and iPad; `Snap` on the home screen. Not on the App Store.

- `docs/superpowers/specs/2026-08-29-snap-design.md` — the pipeline and the contract with the ingest
- `docs/superpowers/specs/2026-08-30-camera-back-design.md` — the camera back, as built
- `docs/superpowers/specs/2026-08-31-chrome-release-design.md` — the chrome release, sounds and haptics, as built
- `docs/superpowers/plans/2026-08-29-snap.md` — how it was built
- `Packages/SnapCore` — the tested part: `cd Packages/SnapCore && swift test`
- `AfterworkSnap/` — the app; open `AfterworkSnap.xcodeproj` with Xcode-beta 27; while Xcode Run refuses a newer iOS device beta, build with ⌘B and push with `devicectl` (see the 08-31 spec)
- `upload.php` — the endpoint; `snap.afterworkphotos.com` pulls `main`
- `index.html` — the page at snap.afterworkphotos.com

Secrets, both gitignored, never committed: `AfterworkSnap/Secrets.xcconfig` (the app secret and the Anthropic key, built into the app) and `snap-secret.php` (the app secret plus the GitHub token, copied to the server by hand). The GitHub token expires; when uploads answer 401, make a new one.
