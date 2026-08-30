# afterworksnap — the camera back: design

Date: 2026-08-30. Status: **designed, not built.** Builds on
`2026-08-29-snap-design.md` (the pipeline, the endpoint, the contract with
`ingest.sh`), which stays in force except where this document says otherwise.
Mockup of record: `2026-08-30-camera-back-mockup.html` beside this file (v30 of
the brainstorm; open it in a browser — four iPhones: live, just snapped,
choosing a name, failed send). The two body textures live in
`AfterworkSnap/Assets.xcassets/LeatherDark|LeatherLight.imageset`.

## What changes

The one screen is redrawn as the back of a camera. Everything the site's
phone layout fixes — the title band, the print's place, its 92 % width and
4 % margins, its letterpress recess, its colours in light and dark — is kept
to the point; around it the phone becomes a textured camera body with a red
shutter, a three-line LCD, a wheel and two slides. The app gets German, an AI
name for each photo with alternatives to choose from by wheel, and nothing to
type: what the LCD shows is what gets posted. Vertical only, on iPhone and
iPad alike; the status bar is hidden.

## Screen, in points (iPhone 393 × 852; the iPad scales the same arrangement)

| element | position | notes |
|---|---|---|
| status bar | hidden | the island sits in the title band's middle; the title is at the right |
| title band | top 12, height 44, left 4 %, right 4 % + 3 | just `snap`, in the site's link colour (`blue` / `#9db8ff` dark), 17 pt semibold, right-aligned; the 3 pt is the site's optical text inset, so title and print share one right edge |
| print (viewfinder) | top 56, left 4 %, width 92 %, square | the site's deck print: 6 pt corners; outside `0 1px 0 edge-light, 1px 0 0 rgba(255,255,255,.3)`; inside `inset 0 3px 4px rgba(shade,.45), inset 0 1px 0 rgba(shade,.35), inset 3px 0 4px rgba(shade,.22), inset 0 -1px 0 rgba(255,255,255,.12)`; shade `40,30,20` light, `0,0,0` dark; edge-light `rgba(255,255,255,.55)` / `.14`. Never carries text. |
| logo `Snap` | 24 below the print, centred, 26 pt italic black-weight serif | silver gradient fill (`#fdfdfb → #b8b8b4 → #8d8d89 → #dcdcd8`), thin black glossy outline; a physical badge |
| shutter | 24 below the logo, Ø 96, centred | red, glossy (`#ff5a4e → #c8100a → #8e0500`), ridged collar. **Naming:** a lit layer (`#ff8a7e → #e8281e`, red halo) breathes over it, 1.6 s. **Failed send:** a darker layer (`#6a0400 → #3a0200`) breathes at half speed, 3.2 s. |
| wheel | Ø 72, right 4 %, bottom edge 12 above the LCD | always present: ridged rim, domed centre button with Font Awesome `arrows-rotate` in the site's blue. Before a shot: greyed — desaturated and dimmed, fully opaque, icon `#7a7a7a` |
| LCD | 4 % sides, height 78, 32 below the shutter | green-grey (`#c9d3c2 → #b9c4b2`), ink `#1b2a1b`, recessed, black 4 pt bezel; monospace 14 pt; three rows, labels 10 pt at the left, empty content `-` |
| retake slide | bottom 30, left 4 %, 104 × 40 | mirrored: knob at rest at the inner (right) end, slides outward to the left; label 20 pt from the track's left end |
| post slide | bottom 30, right 4 %, 104 × 40 | knob at rest at the inner (left) end, slides outward to the right; label 14 pt from the track's right end |

**Slides.** Track mid-grey `#8c8c8c`, knob Ø 32 domed; the label is white
at all times, also when inactive (only the knob greys). While the knob
moves, the track fills behind it — red `#c8100a` for retake, green `#1a9a3a`
for post — the resting label hides and the same word shows fixed in the
filled part. Release past 85 % of the travel fires; below, the knob snaps
back. The slides look the same in both modes.

### Body material

A soft pebble relief, generated (random grain → blur → lit from the
top-left), seamless, tiled at 150 pt. Two PNGs in the asset catalog:
`leather-dark` (contrast −78) on `#161616`, `leather-light` (contrast −76,
tinted) on `#dedede` — the site's paper tone. Over it a wide radial top
light. Buttons are domed (radial highlight top-left, dark rim, small drop
shadow). Mode follows the system.

## States

1. **Live.** Viewfinder runs. LCD rows all `-`. Wheel greyed. Both slides
   inactive (knob greyed, label white). Tap the shutter.
2. **Naming.** The captured square stands in the viewfinder. `loc` and
   `date` fill at once (from the fix and the EXIF); `name` shows `…` and the
   shutter breathes until the first six AI names arrive (≈ 1–3 s); the first
   stands in the row without a number. Wheel and slides become live as soon
   as the shot exists. If the AI fails, `name` stays `-`; posting is still
   possible.
3. **Choosing.** Turning the wheel — or swiping the `name` row — steps
   through the six names; from the first turn on the row is inverted and
   reads `[n] <name>`. The centre button asks for six new ones (the shutter
   breathes again meanwhile). Nothing is typed, in any row.
4. **Post.** Slide: the square is encoded once with the LCD's name, place
   and date in its metadata, written to the library as a favorite and sent.
   `SENT` shows inverted at the right end of the last LCD row for one
   second, then live.
5. **Failed send.** The shot stays. `SENDING ERROR` (de: `SENDEFEHLER`)
   stands inverted at the right end of the last LCD row, twitching one
   letter right–left–right every 1.2 s; the shutter breathes darker at half
   speed; the post slide reads `RETRY` / `ERNEUT`. Retake drops the shot.
6. **Retake** from any state after a shot: back to live; nothing is saved.

## Language

The system language at launch: German if it starts with `de`, English
otherwise. No switch.

| key | en | de |
|---|---|---|
| lcd labels | name · loc · date | name · ort · datum |
| retake | RETAKE | NOCHMAL |
| post | POST | POSTEN |
| retry | RETRY | ERNEUT |
| sent | SENT | GESENDET |
| sending error | SENDING ERROR | SENDEFEHLER |

The AI names are asked for in the language in use.

## The AI names

Asked from the phone with an Anthropic API key in
`AfterworkSnap/Secrets.xcconfig` (gitignored, beside the app secret; reaches
the app through Info.plist like `UPLOAD_SECRET`). Honest limit, accepted: the
key is readable to anyone holding the unlocked phone and its bundle;
rotating it is a rebuild. Model `claude-haiku-4-5`, the 200 px thumbnail as
input (as the ingest sends), one request returning **six** alternatives as a
JSON array of strings; the ingest's own caption prompt, extended by "give six
different candidates, most literal first" and the language. 30 s timeout;
any failure leaves `name` at `-`. Cost ≈ half a cent per request.

## Where the values go: inside the JPEG

At post time the square is encoded once (crop + all metadata, as the
2026-08-29 spec's single encode), and that one file goes both to the library
and to the endpoint — identical copies:

| LCD row | written to | read by `ingest.sh` as |
|---|---|---|
| name | TIFF `ImageDescription` | `%[EXIF:ImageDescription]` → `desc`; Claude is not asked |
| loc | IPTC `City` | `%[IPTC:2:90]` → `place`; the town centre for the map still comes from the GPS via Nominatim |
| date | already `DateTimeOriginal` (never changed) | as now |

An empty `name` writes nothing and the ingest captions as today.

## The contract with `scripts/ingest.sh` (photos repo)

- `desc`: if `%[EXIF:ImageDescription]` is non-empty on the original, use
  it (lower-cased, ≤ 40 chars) and skip `describe()`.
- `place`: if `%[IPTC:2:90]` is non-empty, use it as the name; still
  reverse-geocode the GPS for the town centre coordinate.
- Both cached in `photos.json` by date taken exactly as today.

## SnapCore additions (tested on the host)

- `Metadata.stamp(_ props: inout [CFString: Any], name: String?, place: String?)` —
  merges the two fields; empty or nil writes nothing. Tests: each alone,
  both, empty.
- `SquareCrop.centered(in:gps:extra:)` — the existing single encode takes
  extra properties. Test: name and place read back.
- `NameSuggestions.request(thumbnail: Data, language: String, key: String) -> URLRequest`
  and `NameSuggestions.parse(_ data: Data) -> [String]` — the request as the
  ingest builds it, and the answer to ≤ 6 cleaned strings (lower-case,
  trimmed, ≤ 40 chars, de-duplicated, order kept). Tests: a well-formed
  array; prose around the array; fewer than six; duplicates.
- `Strings` — the table above, keyed by language; a test that every key has
  both languages.
- `Thumbnail.make(from jpeg: Data, side: 200) -> Data` — the model's input.
  Test: output is a 200-px JPEG.

## App target (untested, checked on the device)

`Namer` (one URLSession call), `WheelView` (rotation angle → steps of 30°;
also a horizontal swipe on the `name` row), `SlideView` (drag with the 85 %
threshold, mirrored variant, fill colour, label swap), `LCDView`, `Leather`
(the tiled image as a `ShapeStyle`), the shutter's two breathing layers, and
`AppModel` with the phases above. Status bar hidden; the layout ignores the
top safe area and uses the constants above. iPad: the same constants scaled
by width/393, vertical only.

## Testing

- `swift test` for the SnapCore additions.
- On the device, per state: the shutter breathes and stops; the wheel steps
  1–6 both ways and by swipe; centre fetches six new; a post arrives on the
  site with that name and that place and the ingest log shows neither
  `desc for` nor `place for`; the library copy carries the same name; a post
  with `name` = `-` behaves as today; failed send shows `SENDING ERROR`,
  retry works once, one photo on the site.
- One photo through the whole path in German.

## Not in scope

Landscape on any device. Typing anything. A settings screen. Editing after
posting. Any change to the site's own pages.
