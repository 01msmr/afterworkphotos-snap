# afterworksnap — the camera back: design

Date: 2026-08-30. Status: **designed, not built.** Builds on
`2026-08-29-snap-design.md` (the pipeline, the endpoint, the contract with
`ingest.sh`), which stays in force except where this document says otherwise.
Mockup of record: `.superpowers/brainstorm/13505-1788088646/content/flow-v11.html`
(gitignored, on this Mac).

## What changes

The one screen is redrawn as the back of a camera. Everything the site's
phone layout fixes — the title band, the print's place, its 92 % width and
4 % margins, its letterpress recess, its colours in light and dark — is kept
to the point; around it the phone becomes a textured camera body with a red
shutter, a three-line LCD, an Edit wheel and two slides. The app gets
German, an AI name for each photo with alternatives to choose from, and the
ability to correct name, place and date before posting. Vertical only, on
iPhone and iPad alike; the status bar is hidden.

## Screen, in points (iPhone 393 × 852; iPad scales the same arrangement)

| element | position | notes |
|---|---|---|
| status bar | hidden | the island sits in the title band's middle; the title is at the right |
| title band | top 12, height 44, 4 % sides | `snap` in the site's link colour (`blue` / `#9db8ff` dark), `.afterworkphotos` in the title colour (`#000` / `#fff`); right-aligned, 17 pt semibold |
| print (viewfinder) | top 56, left 4 %, width 92 %, square | the site's deck print: 6 pt corners; `0 1px 0 edge-light, 1px 0 0 rgba(255,255,255,.3)` outside; inside `inset 0 3px 4px rgba(shade,.45), inset 0 1px 0 rgba(shade,.35), inset 3px 0 4px rgba(shade,.22), inset 0 -1px 0 rgba(255,255,255,.12)`; shade `40,30,20` light, `0,0,0` dark. Never carries text. |
| logo `Snap` | 24 below the print, centred, 26 pt | silver gradient fill, thin black glossy outline; a physical badge on the body |
| shutter | 24 below the logo, Ø 96, centred | red, glossy (`#ff5a4e → #c8100a → #8e0500`), a ridged collar; glows while the AI is naming: 1.4 s between a dark red (`#7a0500`) and a lit red (`#e0201a`) with a soft red halo |
| Edit / wheel | Ø 72, right 4 %, bottom edge 12 above the LCD | one spot, two objects: the round *Edit* button, replaced instantly by the wheel when tapped |
| LCD | 4 % sides, height 78, 32 below the shutter | green-grey (`#c9d3c2 → #b9c4b2`), dark ink `#1b2a1b`, recessed with a black 4 pt bezel; monospace 14 pt; three rows, labels 10 pt at the left (`name · loc · date` / `name · ort · datum`), empty content shown as `-` |
| retake slide | bottom 30, left 4 %, 96 × 44 | mid-grey track `#8c8c8c`, white label, knob; track turns red (`#c8100a`) behind the knob as it slides; releases at the end |
| post slide | bottom 30, right 4 %, 96 × 44 | same, turns green (`#1a9a3a`) |

The slides look the same in both modes. Everything else follows the mode.

### Body material

Leather grain, from the camera photographs: an SVG turbulence tile (64 px,
`baseFrequency 0.75`, 3 octaves, desaturated, alpha 0–0.55) over a radial
gradient. Light: `#d4d4d0 → #a9a9a5`. Dark: `#2c2c2c → #0f0f0f`. Buttons are
domed (radial highlight top-left, dark rim, small drop shadow). Mode follows
the system, automatically.

## States

1. **Live.** Viewfinder runs. LCD rows all `-`. Edit greyed. Both slides
   greyed (knob dimmed, label at 45 %). Tap the shutter.
2. **Naming** (right after the shot). The captured square stands in the
   viewfinder. The LCD shows `loc` and `date` at once (from the fix and the
   EXIF); `name` shows `…` and the shutter pulses until the three AI names
   arrive (≈ 1–3 s); then the first stands in the row, without a number. The
   library save happens here too, in the background. Edit and both slides
   become live as soon as the shot exists. If the AI fails, `name` stays `-`;
   posting is still possible.
3. **Review.** LCD filled. *Post* slides to send as is; *retake* slides to
   drop the shot and return to live (the library copy stays — it is the
   archive).
4. **Editing.** Edit becomes the wheel. The `name` row inverts and reads
   `[1] <name>`. Turning the wheel — or swiping the row — steps 1 → 2 → 3
   and back; the number and the text follow. The centre button (Font
   Awesome `arrows-rotate`, in the site's blue) asks for three new names.
   Tapping the `name` row places a cursor: type freely (the number
   disappears; typed text is a fourth option the wheel returns to). Tapping
   `loc` or `date` moves the inversion there for typing; the wheel steps
   only the name, never the other rows. *Post* from here accepts everything
   in the LCD and sends. *Retake* from here drops the shot as in 3.
5. **Sending / sent / failed** as before: progress, then back to live; on
   failure the shot stays, the LCD shows the endpoint's one-line answer in
   place of the `name` row for as long as the failure stands, *post* reads
   `retry` / `erneut senden`.

The wheel and the Edit button are the same control in two states; nothing
else on screen moves between states.

## Language

The system language decides, at launch: German if it starts with `de`,
English otherwise. No switch.

| key | en | de |
|---|---|---|
| lcd labels | name · loc · date | name · ort · datum |
| retake | RETAKE | NOCHMAL |
| post | POST | POSTEN |
| retry (post slide after a failed send) | RETRY | ERNEUT SENDEN |
| edit | Edit | Bearbeiten |
| no place (loc row when there is no fix) | - | - |
| saved, not sent | Saved — not sent. | Gespeichert — nicht gesendet. |
| no upload secret | No upload secret on this phone. | Kein Upload-Geheimnis auf diesem Telefon. |

The AI name is asked for in the language in use.

## The AI name

Asked from the phone, directly, with an Anthropic API key held in
`AfterworkSnap/Secrets.xcconfig` (gitignored, beside the app secret; reaches
the app through Info.plist like `UPLOAD_SECRET`). Honest limit, accepted:
the key is readable to anyone holding the unlocked phone and its bundle;
rotating it is a rebuild. Model `claude-haiku-4-5`, the 200 px thumbnail as
input (the same the ingest sends), one request returning three
alternatives as a JSON array; the ingest's own caption prompt, extended by
"give three different candidates" and the language. 30 s timeout; any
failure leaves `name` at `-`.

The site's `describe()` never runs for a photo that arrives with a name
(see *The contract*), so a photo costs one call, not two.

## Where the edits go: inside the JPEG

At post time the app rewrites the square's metadata once more, in the same
single encode as the crop (the crop is deferred to post time; the review
image is the full capture, shown cropped):

| LCD row | written to | read by `ingest.sh` as |
|---|---|---|
| name | TIFF `ImageDescription` (`kCGImagePropertyTIFFImageDescription`) | `%[EXIF:ImageDescription]` → `desc` |
| loc | IPTC `City` (`kCGImagePropertyIPTCCity`) | `%[IPTC:2:90]` → `place` (the town centre for the map still comes from the GPS via Nominatim; a place typed without any GPS gets no map coordinate) |
| date | EXIF `DateTimeOriginal`, date part only; the time of day stays the capture's | as now: naming, ordering, duplicate check |

An empty row writes nothing, and the ingest behaves as today (Claude for
the caption, Nominatim for the place). The library copy is saved at the
moment of the shot, before any edit — it is the archive of what the camera
saw, not of what was posted.

## The contract with `scripts/ingest.sh` (changes in the photos repo)

- `desc`: if `%[EXIF:ImageDescription]` is non-empty on the original, use
  it (lower-cased, ≤ 40 chars, as `describe()` would) and do not call
  Claude.
- `place`: if `%[IPTC:2:90]` is non-empty, use it as the name; still
  reverse-geocode the GPS for the town centre coordinate when there is GPS.
- Both are cached in `photos.json` by date taken exactly as today; nothing
  else changes.

## SnapCore additions (tested on the host)

- `Metadata.stamp(_ props: inout [CFString: Any], name: String?, place: String?, date: String?)`
  — merges the three fields into a properties dictionary; date replaces the
  date part of `DateTimeOriginal`, keeping its time. Tests: each field
  alone, all three, empty strings write nothing, the date keeps the time.
- `SquareCrop.centered(in:gps:extra:)` — the existing single encode takes
  the extra properties too. Test: the round trip reads back all three.
- `NameSuggestions.parse(_ data: Data) -> [String]` — the model's answer to
  three cleaned strings (lower-case, trimmed, ≤ 40 chars, de-duplicated).
  Tests: a well-formed array, prose around the array, fewer than three.
- `Strings` — the table above as an enum keyed by language code; a test
  that every key has both languages.

## App target (untested, checked on the device)

`Namer` (URLSession call to Anthropic, builds the request from
`NameSuggestions`), `WheelView` (a rotary gesture: angle → steps; also
accepts a horizontal swipe on the LCD row), `SlideView` (a drag with a
threshold at 85 % of the track; snaps back below it; the fill colour follows
the knob), `LCDView`, the body material as a `ShapeStyle`, and `AppModel`
grown by the naming and editing phases. Status bar hidden
(`UIStatusBarHidden` + `.statusBarHidden()`); the layout ignores the top safe
area on purpose and uses the constants above.

## iPad

The same arrangement, the site's iPad measures: 4 % sides, the print 92 %
wide up to the height allows; below it the same five rows with the same
gaps. Vertical only, like the phone.

## Testing

- `swift test` for the SnapCore additions.
- On the device, per state: the shutter pulses and stops; the wheel steps
  1–2–3 both ways and by swipe; typing in each row; a post with all three
  edited arrives on the site with that name, that place, that date, and the
  ingest log shows neither `desc for` nor `place for` (both came with the
  photo); a post with nothing edited behaves as today.
- One photo through the whole path in German.

## Not in scope

Landscape on any device. A settings screen. Editing after posting. More
than three suggestions at a time. Any change to the site's own pages.
