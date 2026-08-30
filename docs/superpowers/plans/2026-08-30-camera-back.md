# Camera Back Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redraw the app's one screen as a camera back per the spec — leather body, the site's print and title, a red shutter, a six-name AI wheel, a three-line LCD, two slides — in English and German, light and dark; post one encode with name and place in its metadata to both the library and the site.

**Architecture:** Pure additions to `SnapCore` (strings, metadata stamping, thumbnail, the Anthropic request/response, the taken date) are host-tested. The app target gets five small views (shutter, wheel, slide, LCD, logo), a leather `ShapeStyle`, a `Namer`, a place lookup, and an `AppModel` rewritten around the spec's phases. `ingest.sh` in the photos repo learns to read the two metadata fields.

**Tech Stack:** Swift 6.3 / Xcode-beta 27, Swift Testing, SwiftUI, ImageIO, CoreLocation (`CLGeocoder`), URLSession → `api.anthropic.com` (`claude-haiku-4-5`). ImageMagick 7 on the Mac for one check.

**Spec:** `docs/superpowers/specs/2026-08-30-camera-back-design.md` (mockup of record beside it: `2026-08-30-camera-back-mockup.html`).

## Global Constraints

- `SnapCore` imports only Foundation, CoreGraphics, ImageIO, UniformTypeIdentifiers. No tests in the app target; no mocking of Apple frameworks.
- Do not edit `project.pbxproj`. `Info.plist` and `Secrets.xcconfig` may be edited (they are not the project file).
- Build check: `cd "/Users/uli/github projects/afterworkphotos-snap" && DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project AfterworkSnap.xcodeproj -scheme AfterworkSnap -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|warning: [^M]|BUILD "` — must end `** BUILD SUCCEEDED **` with no `error:` and no warning lines.
- Tests: `cd "/Users/uli/github projects/afterworkphotos-snap/Packages/SnapCore" && swift test`.
- Layout constants (iPhone points; iPad = same × width/393): title band top 12 h 44, right inset 3; print top 56, left 4 %, width 92 %, radius 6; logo 24 below print, 26 pt; shutter 24 below logo, Ø 96; wheel Ø 72 at right 4 %, bottom 12 above LCD; LCD 32 below shutter, h 78, 4 % sides; slides bottom 30, 104 × 40, knob Ø 32, labels 16 from the outer end; slide fires past 85 % travel.
- Colours: title `blue` / `#9db8ff`; shutter `#ff5a4e → #c8100a → #8e0500`; breathing layer `#6a0400 → #3a0200`, 3.2 s; LCD `#c9d3c2 → #b9c4b2`, ink `#1b2a1b`; slides track `#8c8c8c`, red `#c8100a`, green `#1a9a3a`; body `#dedede` / `#161616` under `LeatherLight` / `LeatherDark` tiled at 150 pt; print shade `40,30,20` / `0,0,0`, edge-light `.55` / `.14`; logo silver `#fdfdfb → #b8b8b4 → #8d8d89 → #dcdcd8`.
- Strings exactly as the spec's table (en / de). Language = system language at launch: `de*` → German, else English.
- AI: six names, `claude-haiku-4-5`, 200 px thumbnail, 30 s timeout, key from Info.plist `ANTHROPIC_API_KEY` (via `Secrets.xcconfig`).
- Metadata at post: name → TIFF `ImageDescription`; place → IPTC `City`; date untouched. One encode → library + endpoint.
- After a shot the shutter is locked until retake or a finished post. `Post sent.` stands 9 s. `SENDING ERROR` twitches 8 pt right and back, 1 s per position.
- Commit after each green step; commit messages end with:

```
Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01YQ8A2LhHfD9PKc3g17tSd4
```

---

## File structure

```
Packages/SnapCore/Sources/SnapCore/
  Strings.swift              Task 1  — the language table
  TakenDate.swift            Task 2  — "yyyy-MM-dd" from DateTimeOriginal
  Metadata.swift             Task 3  — stamp name/place into properties
  SquareCrop.swift           Task 3  — gains `extra:`
  Thumbnail.swift            Task 4  — 200 px JPEG
  NameSuggestions.swift      Task 5  — request + parse
Packages/SnapCore/Tests/SnapCoreTests/
  StringsTests.swift, TakenDateTests.swift, MetadataTests.swift,
  SquareCropTests.swift (+2), ThumbnailTests.swift, NameSuggestionsTests.swift
afterworkphotos/scripts/ingest.sh            Task 6  — read ImageDescription / IPTC City
AfterworkSnap/
  Secrets.xcconfig, Info.plist               Task 7  — ANTHROPIC_API_KEY, status bar hidden
  Namer.swift                                Task 7
  LocationSource.swift                       Task 7  — + placeName()
  Theme.swift                                Task 8  — colours, leather, metrics
  LogoView.swift, ShutterButton.swift,
  WheelView.swift, SlideView.swift, LCDView.swift   Task 8
  AppModel.swift                             Task 9  — rewritten
  ContentView.swift                          Task 9  — rewritten
```

---

### Task 1: Strings

**Files:**
- Create: `Packages/SnapCore/Sources/SnapCore/Strings.swift`, `Packages/SnapCore/Tests/SnapCoreTests/StringsTests.swift`

**Interfaces:**
- Produces: `public enum Language: String { case en, de; static func from(systemCode: String) -> Language }` and `public enum Strings { static func t(_ key: Strings.Key, _ lang: Language) -> String }` with `Key` cases: `name, loc, date, retake, post, retry, postSent, sendingError, empty`.

- [ ] **Step 1: failing tests**

```swift
import Testing
@testable import SnapCore

@Suite struct StringsTests {
    @Test func languageFromSystemCode() {
        #expect(Language.from(systemCode: "de-DE") == .de)
        #expect(Language.from(systemCode: "de") == .de)
        #expect(Language.from(systemCode: "en-GB") == .en)
        #expect(Language.from(systemCode: "fr") == .en)
    }
    @Test func everyKeyHasBothLanguages() {
        for key in Strings.Key.allCases {
            #expect(!Strings.t(key, .en).isEmpty)
            #expect(!Strings.t(key, .de).isEmpty)
        }
    }
    @Test func theTable() {
        #expect(Strings.t(.retake, .de) == "NOCHMAL")
        #expect(Strings.t(.postSent, .en) == "Post sent.")
        #expect(Strings.t(.sendingError, .de) == "SENDEFEHLER")
        #expect(Strings.t(.loc, .de) == "ort")
        #expect(Strings.t(.empty, .en) == "-")
    }
}
```

- [ ] **Step 2: run, expect** `cannot find 'Language' in scope`.

- [ ] **Step 3: implement**

```swift
import Foundation

public enum Language: String, Sendable {
    case en, de
    /// The system language at launch: German if it starts with "de".
    public static func from(systemCode: String) -> Language {
        systemCode.lowercased().hasPrefix("de") ? .de : .en
    }
}

public enum Strings {
    public enum Key: CaseIterable, Sendable {
        case name, loc, date, retake, post, retry, postSent, sendingError, empty
    }
    public static func t(_ key: Key, _ lang: Language) -> String {
        switch (key, lang) {
        case (.name, _):          "name"
        case (.loc, .en):         "loc"
        case (.loc, .de):         "ort"
        case (.date, .en):        "date"
        case (.date, .de):        "datum"
        case (.retake, .en):      "RETAKE"
        case (.retake, .de):      "NOCHMAL"
        case (.post, .en):        "POST"
        case (.post, .de):        "POSTEN"
        case (.retry, .en):       "RETRY"
        case (.retry, .de):       "ERNEUT"
        case (.postSent, .en):    "Post sent."
        case (.postSent, .de):    "Gesendet."
        case (.sendingError, .en): "SENDING ERROR"
        case (.sendingError, .de): "SENDEFEHLER"
        case (.empty, _):         "-"
        }
    }
}
```

- [ ] **Step 4: run, expect pass.** - [ ] **Step 5: commit** `Strings: the en/de table`.

---

### Task 2: TakenDate

**Files:**
- Create: `Packages/SnapCore/Sources/SnapCore/TakenDate.swift`, `Packages/SnapCore/Tests/SnapCoreTests/TakenDateTests.swift`

**Interfaces:**
- Produces: `public enum TakenDate { static func from(jpeg: Data) -> String? }` → `"2026-08-30"` or nil.

- [ ] **Step 1: failing tests**

```swift
import Testing
import Foundation
import ImageIO
@testable import SnapCore

@Suite struct TakenDateTests {
    @Test func dateFromExif() {
        let jpeg = TestJPEG.make(width: 40, height: 30, exif: [kCGImagePropertyExifDateTimeOriginal: "2026:08:30 15:39:12"])
        #expect(TakenDate.from(jpeg: jpeg) == "2026-08-30")
    }
    @Test func nilWithoutDate() {
        #expect(TakenDate.from(jpeg: TestJPEG.make(width: 40, height: 30)) == nil)
        #expect(TakenDate.from(jpeg: Data([1, 2, 3])) == nil)
    }
}
```

- [ ] **Step 2: run, expect** `cannot find 'TakenDate'`.

- [ ] **Step 3: implement**

```swift
import Foundation
import ImageIO

public enum TakenDate {
    /// "yyyy-MM-dd" from EXIF DateTimeOriginal ("yyyy:MM:dd HH:mm:ss"); nil without one.
    public static func from(jpeg: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let taken = exif[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }
        let d = taken.filter(\.isNumber)
        guard d.count == 14 else { return nil }
        return "\(d.prefix(4))-\(d.dropFirst(4).prefix(2))-\(d.dropFirst(6).prefix(2))"
    }
}
```

- [ ] **Step 4: run, expect pass.** - [ ] **Step 5: commit** `TakenDate: yyyy-MM-dd from DateTimeOriginal`.

---

### Task 3: Metadata stamp, and the crop takes it

**Files:**
- Create: `Packages/SnapCore/Sources/SnapCore/Metadata.swift`, `Packages/SnapCore/Tests/SnapCoreTests/MetadataTests.swift`
- Modify: `Packages/SnapCore/Sources/SnapCore/SquareCrop.swift`, `Packages/SnapCore/Tests/SnapCoreTests/SquareCropTests.swift`

**Interfaces:**
- Produces: `public enum Metadata { static func stamp(_ props: inout [CFString: Any], name: String?, place: String?) }`; `SquareCrop.centered(in:gps:extra:)` with `extra: [CFString: Any]? = nil` merged on top (dictionary values for `TIFF` and `IPTC` are merged key-wise, not replaced).

- [ ] **Step 1: failing tests**

`MetadataTests.swift`:
```swift
import Testing
import ImageIO
@testable import SnapCore

@Suite struct MetadataTests {
    @Test func nameGoesToTiffImageDescription() {
        var p: [CFString: Any] = [:]
        Metadata.stamp(&p, name: "white keyboard", place: nil)
        let tiff = p[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(tiff?[kCGImagePropertyTIFFImageDescription] as? String == "white keyboard")
        #expect(p[kCGImagePropertyIPTCDictionary] == nil)
    }
    @Test func placeGoesToIptcCity() {
        var p: [CFString: Any] = [:]
        Metadata.stamp(&p, name: nil, place: "Markdorf")
        let iptc = p[kCGImagePropertyIPTCDictionary] as? [CFString: Any]
        #expect(iptc?[kCGImagePropertyIPTCCity] as? String == "Markdorf")
        #expect(p[kCGImagePropertyTIFFDictionary] == nil)
    }
    @Test func emptyWritesNothingAndKeepsExisting() {
        var p: [CFString: Any] = [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Apple"]]
        Metadata.stamp(&p, name: "", place: "  ")
        let tiff = p[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(tiff?[kCGImagePropertyTIFFMake] as? String == "Apple")
        #expect(tiff?[kCGImagePropertyTIFFImageDescription] == nil)
        #expect(p[kCGImagePropertyIPTCDictionary] == nil)
    }
}
```

Add to `SquareCropTests`:
```swift
    @Test func extraPropertiesAreWrittenInTheSameEncode() throws {
        let input = TestJPEG.make(width: 40, height: 30, tiff: [kCGImagePropertyTIFFMake: "Apple"])
        var extra: [CFString: Any] = [:]
        Metadata.stamp(&extra, name: "white keyboard", place: "Markdorf")
        let p = TestJPEG.properties(of: try SquareCrop.centered(in: input, extra: extra))
        let tiff = p[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(tiff?[kCGImagePropertyTIFFImageDescription] as? String == "white keyboard")
        #expect(tiff?[kCGImagePropertyTIFFMake] as? String == "Apple")   // merged, not replaced
        let iptc = p[kCGImagePropertyIPTCDictionary] as? [CFString: Any]
        #expect(iptc?[kCGImagePropertyIPTCCity] as? String == "Markdorf")
    }
```

- [ ] **Step 2: run, expect** `cannot find 'Metadata'` / `extra argument`.

- [ ] **Step 3: implement**

`Metadata.swift`:
```swift
import Foundation
import ImageIO

public enum Metadata {
    /// The LCD's name and place, into the fields the site's ingest reads:
    /// TIFF ImageDescription and IPTC City. Empty writes nothing.
    public static func stamp(_ props: inout [CFString: Any], name: String?, place: String?) {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            var tiff = (props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]) ?? [:]
            tiff[kCGImagePropertyTIFFImageDescription] = name
            props[kCGImagePropertyTIFFDictionary] = tiff
        }
        if let place = place?.trimmingCharacters(in: .whitespacesAndNewlines), !place.isEmpty {
            var iptc = (props[kCGImagePropertyIPTCDictionary] as? [CFString: Any]) ?? [:]
            iptc[kCGImagePropertyIPTCCity] = place
            props[kCGImagePropertyIPTCDictionary] = iptc
        }
    }
}
```

`SquareCrop.swift` — signature `public static func centered(in data: Data, gps: [CFString: Any]? = nil, extra: [CFString: Any]? = nil) throws -> Data`, and after the `if let gps` line:
```swift
        if let extra {
            for (key, value) in extra {
                if let sub = value as? [CFString: Any], var existing = props[key] as? [CFString: Any] {
                    for (k, v) in sub { existing[k] = v }
                    props[key] = existing
                } else {
                    props[key] = value
                }
            }
        }
```

- [ ] **Step 4: run, expect pass.** - [ ] **Step 5: commit** `Metadata: name and place into TIFF/IPTC; SquareCrop takes extra properties`.

---

### Task 4: Thumbnail

**Files:**
- Create: `Packages/SnapCore/Sources/SnapCore/Thumbnail.swift`, `Packages/SnapCore/Tests/SnapCoreTests/ThumbnailTests.swift`

**Interfaces:**
- Produces: `public enum Thumbnail { static func make(from jpeg: Data, side: Int = 200) throws -> Data }` — JPEG, longest side ≤ `side`.

- [ ] **Step 1: failing test**

```swift
import Testing
import Foundation
import ImageIO
@testable import SnapCore

@Suite struct ThumbnailTests {
    @Test func twoHundredPixelJpeg() throws {
        let out = try Thumbnail.make(from: TestJPEG.make(width: 3000, height: 3000))
        let p = TestJPEG.properties(of: out)
        #expect(p[kCGImagePropertyPixelWidth] as? Int == 200)
        #expect(out.prefix(3) == Data([0xFF, 0xD8, 0xFF]))
    }
    @Test func garbageThrows() {
        #expect(throws: SnapError.decodeFailed) { try Thumbnail.make(from: Data([1, 2])) }
    }
}
```

- [ ] **Step 2: run, expect** `cannot find 'Thumbnail'`.

- [ ] **Step 3: implement**

```swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum Thumbnail {
    /// A small JPEG for the model to look at — the size the ingest sends.
    public static func make(from jpeg: Data, side: Int = 200) throws -> Data {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil) else { throw SnapError.decodeFailed }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                     kCGImageSourceThumbnailMaxPixelSize: side,
                                     kCGImageSourceCreateThumbnailWithTransform: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) else { throw SnapError.decodeFailed }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { throw SnapError.encodeFailed }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw SnapError.encodeFailed }
        return out as Data
    }
}
```

- [ ] **Step 4: run, expect pass.** - [ ] **Step 5: commit** `Thumbnail: 200 px JPEG for the model`.

---

### Task 5: NameSuggestions — the request and the answer

**Files:**
- Create: `Packages/SnapCore/Sources/SnapCore/NameSuggestions.swift`, `Packages/SnapCore/Tests/SnapCoreTests/NameSuggestionsTests.swift`

**Interfaces:**
- Produces: `public enum NameSuggestions { static func request(thumbnail: Data, language: Language, key: String) -> URLRequest; static func parse(_ body: Data) -> [String] }`. The request is POST `https://api.anthropic.com/v1/messages`, headers `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`, timeout 30; body model `claude-haiku-4-5`, `max_tokens` 200, the ingest's system prompt plus the six-candidates instruction; the image as base64 JPEG. `parse` takes the Messages API response, finds the first `text` content block, extracts the first `[...]` JSON array of strings, cleans each (trim, lower-case, ≤ 40 chars), de-duplicates keeping order, returns at most 6.

- [ ] **Step 1: failing tests**

```swift
import Testing
import Foundation
@testable import SnapCore

@Suite struct NameSuggestionsTests {
    let thumb = Data([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3])

    @Test func requestShape() throws {
        let r = NameSuggestions.request(thumbnail: thumb, language: .de, key: "k")
        #expect(r.httpMethod == "POST")
        #expect(r.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(r.value(forHTTPHeaderField: "x-api-key") == "k")
        #expect(r.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(r.timeoutInterval == 30)
        let json = try JSONSerialization.jsonObject(with: r.httpBody!) as! [String: Any]
        #expect(json["model"] as? String == "claude-haiku-4-5")
        let system = json["system"] as! String
        #expect(system.contains("six"))
        #expect(system.contains("German"))
        let msgs = json["messages"] as! [[String: Any]]
        let content = msgs[0]["content"] as! [[String: Any]]
        let img = content[0]["source"] as! [String: Any]
        #expect(img["data"] as? String == thumb.base64EncodedString())
    }

    private func reply(_ text: String) -> Data {
        let obj: [String: Any] = ["content": [["type": "text", "text": text]]]
        return try! JSONSerialization.data(withJSONObject: obj)
    }

    @Test func parsesACleanArray() {
        let names = NameSuggestions.parse(reply(#"["White keyboard","desk","keys on desk","White keyboard","Sun over tree ","x","y"]"#))
        #expect(names == ["white keyboard", "desk", "keys on desk", "sun over tree", "x", "y"])
    }
    @Test func parsesProseAroundTheArray() {
        let names = NameSuggestions.parse(reply(#"Here you go: ["forest", "trees"] — hope that helps"#))
        #expect(names == ["forest", "trees"])
    }
    @Test func fewerThanSixIsFine() {
        #expect(NameSuggestions.parse(reply(#"["rails"]"#)) == ["rails"])
    }
    @Test func garbageIsEmpty() {
        #expect(NameSuggestions.parse(Data("nope".utf8)) == [])
        #expect(NameSuggestions.parse(reply("no array here")) == [])
    }
}
```

- [ ] **Step 2: run, expect** `cannot find 'NameSuggestions'`.

- [ ] **Step 3: implement**

```swift
import Foundation

public enum NameSuggestions {
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// The ingest's caption prompt, asked for six candidates in the language in use.
    static func systemPrompt(_ language: Language) -> String {
        let lang = language == .de ? "German" : "English"
        return "You caption photos for an art archive. Give six different candidate captions for the main subject, most literal first, as a JSON array of strings and nothing else. Each is a 1-3 word literal description in lowercase \(lang) (capitals only for letters shown as shapes or stencils: L-shaped, a T, VA), concrete nouns, no article, no punctuation — like: snow on street, forest, clouds in sky, foot, garage door. Be precise about what the object actually is. Name its color only when the color is striking (bright orange, vivid green) — leave ordinary colors like gray or brown out. White may stay when it marks the object itself (white fruit) and the caption is two words, never as a third word. If the subject is geometric (grid, circle, spiral, zigzag, diamond), or the composition has stark geometric elements (a strong diagonal, repetition, symmetry), name that geometry even when it takes an extra word. Mind that snow under warm evening light can look like sand — check texture and season before calling it sandy."
    }

    public static func request(thumbnail: Data, language: Language, key: String) -> URLRequest {
        let body: [String: Any] = [
            "model": "claude-haiku-4-5", "max_tokens": 200,
            "system": systemPrompt(language),
            "messages": [["role": "user", "content": [
                ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg",
                                             "data": thumbnail.base64EncodedString()]],
                ["type": "text", "text": "Caption this photo."]]]],
        ]
        var r = URLRequest(url: endpoint)
        r.httpMethod = "POST"
        r.setValue(key, forHTTPHeaderField: "x-api-key")
        r.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        r.setValue("application/json", forHTTPHeaderField: "content-type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        r.timeoutInterval = 30
        return r
    }

    /// The model's answer → at most six cleaned names, order kept.
    public static func parse(_ body: Data) -> [String] {
        guard let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let content = obj["content"] as? [[String: Any]],
              let text = content.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
              let open = text.firstIndex(of: "["), let close = text[open...].firstIndex(of: "]"),
              let raw = try? JSONSerialization.jsonObject(with: Data(text[open...close].utf8)) as? [String] else {
            return []
        }
        var seen = Set<String>(), out: [String] = []
        for s in raw {
            let clean = String(s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().prefix(40))
            guard !clean.isEmpty, seen.insert(clean).inserted else { continue }
            out.append(clean)
            if out.count == 6 { break }
        }
        return out
    }
}
```

- [ ] **Step 4: run, expect pass.** - [ ] **Step 5: commit** `NameSuggestions: the Anthropic request and six cleaned names`.

---

### Task 6: `ingest.sh` reads the name and the place from the photo (photos repo)

**Files:**
- Modify: `/Users/uli/github projects/afterworkphotos/scripts/ingest.sh` (section 4, around the `place=` and `desc=` lines), `docs/details.md` (*Adding a photo*, step 4)

**Interfaces:**
- Consumes: originals in `img originals/` with `ImageDescription` and/or `IPTC City`.
- Produces: `desc` and `place` in `photos.json` from those fields when present; no Claude call, no name from Nominatim, in that case.

- [ ] **Step 1: two helpers** after `gps_of_photo()`:

```bash
# a name and a place the photo brought with it (the snap app writes them):
# TIFF ImageDescription and IPTC City on the original; empty when absent
desc_in_photo() {
  local o; o=$(original_of "$1"); [[ -n "$o" ]] || return 0
  is_video "$o" && return 0
  identify -quiet -format '%[EXIF:ImageDescription]' "$o" 2>/dev/null \
    | head -1 | tr '[:upper:]' '[:lower:]' | tr -d '"' | cut -c1-40
  return 0
}
place_in_photo() {
  local o; o=$(original_of "$1"); [[ -n "$o" ]] || return 0
  is_video "$o" && return 0
  identify -quiet -format '%[IPTC:2:90]' "$o" 2>/dev/null | head -1 | cut -c1-60
  return 0
}
```

- [ ] **Step 2: use them** in section 4. Replace

```bash
    place=$(place_of "$d" || true)
```
with
```bash
    place=$(place_of "$d" || true)
    [[ -n "$place" ]] || place=$(place_in_photo "$name" || true)
```
and replace
```bash
    desc=$(desc_of "$d" || true)
    if [[ -z "$desc" && -f "img/thumb/$name.jpg" ]]; then
```
with
```bash
    desc=$(desc_of "$d" || true)
    [[ -n "$desc" ]] || desc=$(desc_in_photo "$name" || true)
    if [[ -z "$desc" && -f "img/thumb/$name.jpg" ]]; then
```

- [ ] **Step 3: check by hand** on the Mac with a fixture the app's own code produces (Task 3's test writes one only in memory, so make one):

```bash
cd "/Users/uli/github projects/afterworkphotos-snap/Packages/SnapCore" && cat > Tests/SnapCoreTests/DumpStamped.swift <<'EOF'
import Testing
import Foundation
@testable import SnapCore
@Suite struct DumpStamped { @Test func dump() throws {
    var extra: [CFString: Any] = [:]
    Metadata.stamp(&extra, name: "white keyboard", place: "Markdorf")
    let out = try SquareCrop.centered(in: TestJPEG.make(width: 400, height: 300, exif: [kCGImagePropertyExifDateTimeOriginal: "2026:08:30 15:39:12"]), extra: extra)
    try out.write(to: URL(fileURLWithPath: "/tmp/snap-stamped.jpg"))
} }
EOF
swift test --filter DumpStamped && magick identify -quiet -format '%[EXIF:ImageDescription]|%[IPTC:2:90]\n' /tmp/snap-stamped.jpg
rm Tests/SnapCoreTests/DumpStamped.swift /tmp/snap-stamped.jpg
```
Expected: `white keyboard|Markdorf`. If the IPTC half is empty, ImageIO did not write IPTC into the JPEG — then change `Metadata.stamp` to put the place into EXIF `UserComment` (`kCGImagePropertyExifUserComment`) and `place_in_photo` to read `%[EXIF:UserComment]`, re-run Task 3's tests and this check, and note it in the spec.

- [ ] **Step 4: `bash -n scripts/ingest.sh`**, then update `docs/details.md` step 4: after "…hand-written ones are carried forward the same way." add: "A photo that arrives with a name in its `ImageDescription` (the snap app writes the chosen AI name there) uses it and is not sent to Claude; one with an IPTC `City` uses that as its place (the map coordinate still comes from the GPS)."

- [ ] **Step 5: commit in the photos repo** on `main`, push, and fast-forward `vr-view`:

```bash
cd "/Users/uli/github projects/afterworkphotos" && git add scripts/ingest.sh docs/details.md && git commit -m "ingest: take desc and place from the photo's own ImageDescription / IPTC City when present" && git push origin main && git push origin main:vr-view
```

---

### Task 7: The key, the status bar, the Namer, the place name

**Files:**
- Modify: `AfterworkSnap/Secrets.xcconfig` (gitignored), `AfterworkSnap/Info.plist`, `AfterworkSnap/LocationSource.swift`
- Create: `AfterworkSnap/Namer.swift`

**Interfaces:**
- Produces: `Namer.suggest(for jpeg: Data, language: Language) async -> [String]`; `LocationSource.placeName(for: (Double, Double)) async -> String?`; Info.plist keys `ANTHROPIC_API_KEY = $(ANTHROPIC_API_KEY)`, `UIStatusBarHidden = YES`, `UIViewControllerBasedStatusBarAppearance = NO`.

- [ ] **Step 1: the key.** Append to `AfterworkSnap/Secrets.xcconfig` a line `ANTHROPIC_API_KEY = <the key>` — the user pastes the value (it is the same kind of key as the repo secret; a fresh one from console.anthropic.com is best, so it can be revoked alone). Never commit this file.

- [ ] **Step 2: Info.plist**

```bash
cd "/Users/uli/github projects/afterworkphotos-snap" && /usr/libexec/PlistBuddy -c "Add :ANTHROPIC_API_KEY string \$(ANTHROPIC_API_KEY)" -c "Add :UIStatusBarHidden bool true" -c "Add :UIViewControllerBasedStatusBarAppearance bool false" AfterworkSnap/Info.plist && cat AfterworkSnap/Info.plist
```

- [ ] **Step 3: `Namer.swift`**

```swift
import Foundation
import SnapCore

/// Six names for a photo, from Claude, with the key built into the app.
/// Any failure is an empty list — the LCD then shows "-".
enum Namer {
    static func suggest(for jpeg: Data, language: Language) async -> [String] {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String, !key.isEmpty,
              let thumb = try? Thumbnail.make(from: jpeg) else { return [] }
        let request = NameSuggestions.request(thumbnail: thumb, language: language, key: key)
        guard let (body, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return NameSuggestions.parse(body)
    }
}
```

- [ ] **Step 4: the place name** — add to `LocationSource`:

```swift
    /// The town for a fix, from the device's own geocoder; nil when it has none.
    func placeName(for fix: (Double, Double)) async -> String? {
        let location = CLLocation(latitude: fix.0, longitude: fix.1)
        guard let mark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        return mark.locality ?? mark.subAdministrativeArea
    }
```

- [ ] **Step 5: build** (Global Constraints command). Expected `BUILD SUCCEEDED`.

- [ ] **Step 6: commit** `app: Anthropic key via xcconfig, status bar hidden, Namer, place name` (Info.plist, Namer.swift, LocationSource.swift — `git status` must not list Secrets.xcconfig).

---

### Task 8: Theme and the five camera parts

**Files:**
- Create: `AfterworkSnap/Theme.swift`, `AfterworkSnap/LogoView.swift`, `AfterworkSnap/ShutterButton.swift`, `AfterworkSnap/WheelView.swift`, `AfterworkSnap/SlideView.swift`, `AfterworkSnap/LCDView.swift`

**Interfaces:**
- Produces: `Theme` (colours per scheme, `Metrics` for a width), `LogoView()`, `ShutterButton(locked:breathing:action:)`, `WheelView(enabled:onStep:onCenter:)`, `SlideView(label:colour:mirrored:enabled:onFire:)`, `LCDView(rows:invertedRow:sign:signTwitching:language:onNameSwipe:)`. All views take their sizes from `Metrics`.

- [ ] **Step 1: `Theme.swift`**

```swift
import SwiftUI

/// The spec's constants. Points for a 393-wide screen; `Metrics` scales them.
struct Metrics {
    let scale: CGFloat
    init(width: CGFloat) { scale = width / 393 }
    func pt(_ v: CGFloat) -> CGFloat { v * scale }
    var side: CGFloat { 0.04 }                 // fraction of width
    var titleTop: CGFloat { pt(12) }
    var titleHeight: CGFloat { pt(44) }
    var printTop: CGFloat { pt(56) }
    var gapLogo: CGFloat { pt(24) }
    var logoSize: CGFloat { pt(26) }
    var gapShutter: CGFloat { pt(24) }
    var shutter: CGFloat { pt(96) }
    var wheel: CGFloat { pt(72) }
    var gapLCD: CGFloat { pt(32) }
    var lcdHeight: CGFloat { pt(78) }
    var slideW: CGFloat { pt(104) }
    var slideH: CGFloat { pt(40) }
    var knob: CGFloat { pt(32) }
    var slideBottom: CGFloat { pt(30) }
    var labelInset: CGFloat { pt(16) }
}

enum Theme {
    static let titleBlue = Color(red: 0, green: 0, blue: 1)
    static let titleBlueDark = Color(red: 0x9d/255, green: 0xb8/255, blue: 1)
    static let shutterTop = Color(red: 1, green: 0x5a/255, blue: 0x4e/255)
    static let shutterMid = Color(red: 0xc8/255, green: 0x10/255, blue: 0x0a/255)
    static let shutterEdge = Color(red: 0x8e/255, green: 0x05/255, blue: 0)
    static let breathTop = Color(red: 0x6a/255, green: 0x04/255, blue: 0)
    static let breathEdge = Color(red: 0x3a/255, green: 0x02/255, blue: 0)
    static let lcdTop = Color(red: 0xc9/255, green: 0xd3/255, blue: 0xc2/255)
    static let lcdBottom = Color(red: 0xb9/255, green: 0xc4/255, blue: 0xb2/255)
    static let lcdInk = Color(red: 0x1b/255, green: 0x2a/255, blue: 0x1b/255)
    static let track = Color(red: 0x8c/255, green: 0x8c/255, blue: 0x8c/255)
    static let red = Color(red: 0xc8/255, green: 0x10/255, blue: 0x0a/255)
    static let green = Color(red: 0x1a/255, green: 0x9a/255, blue: 0x3a/255)
    static let siteBlueLight = titleBlue

    static func body(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0x16/255, green: 0x16/255, blue: 0x16/255)
                        : Color(red: 0xde/255, green: 0xde/255, blue: 0xde/255)
    }
    static func title(_ scheme: ColorScheme) -> Color { scheme == .dark ? titleBlueDark : titleBlue }
    /// The print's recess shade (the site's --shade) and edge light.
    static func shade(_ scheme: ColorScheme) -> Color { scheme == .dark ? .black : Color(red: 40/255, green: 30/255, blue: 20/255) }
    static func edgeLight(_ scheme: ColorScheme) -> Color { .white.opacity(scheme == .dark ? 0.14 : 0.55) }
}

/// The leather: the tile from the asset catalog, repeated at 150 pt, under a wide top light.
struct Leather: View {
    @Environment(\.colorScheme) private var scheme
    let metrics: Metrics
    var body: some View {
        ZStack {
            Theme.body(scheme)
            Image(scheme == .dark ? "LeatherDark" : "LeatherLight")
                .resizable(resizingMode: .tile)
                .scaleEffect(metrics.pt(150) / 256, anchor: .topLeading)
                .clipped()
            RadialGradient(colors: [.white.opacity(scheme == .dark ? 0.10 : 0.35), .black.opacity(scheme == .dark ? 0.35 : 0.08)],
                           center: .top, startRadius: 0, endRadius: metrics.pt(900))
        }
        .ignoresSafeArea()
    }
}

/// A domed button face: radial highlight top-left, dark rim, drop shadow.
struct Dome: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .background(
                Circle().fill(RadialGradient(colors: scheme == .dark ? [Color(white: 0.24), Color(white: 0.08)] : [Color(white: 0.95), Color(white: 0.77)],
                                             center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: 60))
            )
            .overlay(Circle().stroke(Color.black.opacity(scheme == .dark ? 1 : 0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
    }
}
```

- [ ] **Step 2: `LogoView.swift`** — silver italic serif with a black outline:

```swift
import SwiftUI

struct LogoView: View {
    let size: CGFloat
    var body: some View {
        let font = Font.system(size: size, weight: .black, design: .serif).italic()
        ZStack {
            Text("Snap").font(font).foregroundStyle(.black)
                .offset(x: 1, y: 1)
            Text("Snap").font(font).foregroundStyle(.black)
                .offset(x: -1, y: -1)
            Text("Snap").font(font)
                .foregroundStyle(LinearGradient(colors: [Color(white: 0.99), Color(white: 0.72), Color(white: 0.55), Color(white: 0.86)],
                                                startPoint: .top, endPoint: .bottom))
        }
        .shadow(color: .white.opacity(0.35), radius: 0, y: -1)
        .shadow(color: .black.opacity(0.6), radius: 0, y: 1)
    }
}
```

- [ ] **Step 3: `ShutterButton.swift`**

```swift
import SwiftUI

/// The red release. `breathing`: the dark layer fades in and out, 3.2 s.
/// `locked`: greyed and inert.
struct ShutterButton: View {
    let size: CGFloat
    let locked: Bool
    let breathing: Bool
    let action: () -> Void
    @State private var lit = false

    var body: some View {
        Button(action: { if !locked { action() } }) {
            ZStack {
                Circle().fill(RadialGradient(colors: [Theme.shutterTop, Theme.shutterMid, Theme.shutterEdge],
                                             center: UnitPoint(x: 0.4, y: 0.32), startRadius: 0, endRadius: size * 0.6))
                Circle().fill(RadialGradient(colors: [Theme.breathTop, Theme.breathEdge],
                                             center: UnitPoint(x: 0.4, y: 0.32), startRadius: 0, endRadius: size * 0.6))
                    .opacity(breathing ? (lit ? 1 : 0) : 0)
                Circle().strokeBorder(.white.opacity(0.45), lineWidth: 3).padding(1).mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
            }
            .overlay(Circle().stroke(Color(red: 0.35, green: 0.01, blue: 0), lineWidth: 1))
            .overlay(Circle().stroke(.black.opacity(0.2), lineWidth: 7).padding(-7))    // the ridged collar
            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1).padding(-8))
            .shadow(color: .black.opacity(0.4), radius: 3, y: 4)
            .saturation(locked ? 0.25 : 1)
            .brightness(locked ? -0.25 : 0)
        }
        .buttonStyle(.plain)
        .frame(width: size, height: size)
        .onChange(of: breathing, initial: true) { _, on in
            guard on else { lit = false; return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { lit = true }
        }
    }
}
```

- [ ] **Step 4: `WheelView.swift`** — a ridged rim you turn (30° per step) and a centre button:

```swift
import SwiftUI

struct WheelView: View {
    let size: CGFloat
    let enabled: Bool
    let onStep: (Int) -> Void      // +1 clockwise, -1 counter-clockwise
    let onCenter: () -> Void
    @State private var lastAngle: Double?
    @State private var accumulated: Double = 0
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Circle().fill(AngularGradient(colors: Array(repeating: [Color(white: scheme == .dark ? 0.3 : 0.85), Color(white: scheme == .dark ? 0.12 : 0.66)], count: 45).flatMap { $0 }, center: .center))
                .overlay(Circle().strokeBorder(Color(white: scheme == .dark ? 0.2 : 0.76), lineWidth: 6))
                .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 3)
                .gesture(DragGesture(minimumDistance: 2).onChanged { g in
                    guard enabled else { return }
                    let c = CGPoint(x: size / 2, y: size / 2)
                    let a = atan2(g.location.y - c.y, g.location.x - c.x)
                    if let last = lastAngle {
                        var d = a - last
                        if d > .pi { d -= 2 * .pi } else if d < -.pi { d += 2 * .pi }
                        accumulated += d
                        let step = Double.pi / 6
                        while accumulated >= step { accumulated -= step; onStep(1) }
                        while accumulated <= -step { accumulated += step; onStep(-1) }
                    }
                    lastAngle = a
                }.onEnded { _ in lastAngle = nil; accumulated = 0 })
            Button(action: { if enabled { onCenter() } }) {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")   // the rotate-arrows glyph
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(enabled ? Theme.titleBlue : Color(white: 0.48))
                    .frame(width: size - 30, height: size - 30)
                    .modifier(Dome())
            }
            .buttonStyle(.plain)
        }
        .frame(width: size, height: size)
        .saturation(enabled ? 1 : 0)
        .brightness(enabled ? 0 : (scheme == .dark ? -0.1 : -0.18))
    }
}
```
(The SF Symbol stands in for Font Awesome's `arrows-rotate`; both are two curved arrows in a circle. If the name does not resolve on iOS 18, use `"arrow.2.circlepath"`.)

- [ ] **Step 5: `SlideView.swift`**

```swift
import SwiftUI

/// A knob you drag along a track. Fires past 85 %; snaps back below.
/// `mirrored`: knob at rest at the right, travels left (retake).
struct SlideView: View {
    let label: String
    let colour: Color
    let mirrored: Bool
    let enabled: Bool
    let metrics: Metrics
    let onFire: () -> Void
    @State private var offset: CGFloat = 0
    @Environment(\.colorScheme) private var scheme

    private var travel: CGFloat { metrics.slideW - metrics.knob - 8 }
    private var progress: CGFloat { offset / travel }

    var body: some View {
        let w = metrics.slideW, h = metrics.slideH, k = metrics.knob
        ZStack(alignment: .leading) {
            Capsule().fill(Theme.track)
                .overlay(Capsule().strokeBorder(.black.opacity(0.45), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 2, y: 2)   // recessed
            Rectangle().fill(colour).frame(width: 4 + offset + k / 2).clipShape(Capsule())
            // resting label: from the knob's far side to the outer end
            Text(label).font(.system(size: metrics.pt(12), weight: .semibold)).foregroundStyle(.white)
                .frame(width: w - k - 8 - metrics.labelInset, alignment: .trailing)
                .offset(x: k + 8)
                .opacity(offset == 0 ? 1 : 0)
            // the same word, fixed on the colour, 16 from the inner end
            Text(label).font(.system(size: metrics.pt(12), weight: .semibold)).foregroundStyle(.white)
                .padding(.leading, metrics.labelInset)
                .opacity(offset == 0 ? 0 : 1)
            Circle().frame(width: k, height: k)
                .modifier(Dome())
                .saturation(enabled ? 1 : 0).brightness(enabled ? 0 : -0.15)
                .offset(x: 4 + offset)
                .gesture(DragGesture().onChanged { g in
                    guard enabled else { return }
                    let dx = mirrored ? -g.translation.width : g.translation.width
                    offset = min(max(0, dx), travel)
                }.onEnded { _ in
                    if enabled && progress >= 0.85 { onFire() }
                    withAnimation(.spring(duration: 0.25)) { offset = 0 }
                })
        }
        .frame(width: w, height: h)
        .scaleEffect(x: mirrored ? -1 : 1)          // the track is mirrored…
        .environment(\.layoutDirection, .leftToRight)
        .overlay {                                 // …the words are not: draw them again unmirrored
            if mirrored {
                ZStack(alignment: .trailing) {
                    Text(label).font(.system(size: metrics.pt(12), weight: .semibold)).foregroundStyle(.white)
                        .padding(.trailing, metrics.labelInset)
                        .opacity(offset == 0 ? 0 : 1)
                }
                .frame(width: w, height: h, alignment: .trailing)
                .overlay(alignment: .leading) {
                    Text(label).font(.system(size: metrics.pt(12), weight: .semibold)).foregroundStyle(.white)
                        .padding(.leading, metrics.labelInset)
                        .opacity(offset == 0 ? 1 : 0)
                }
                .allowsHitTesting(false)
            }
        }
        .mask { if mirrored { Capsule() } else { Rectangle() } }
    }
}
```
Implementer's note: in the mirrored case the two `Text`s inside the mirrored `ZStack` are drawn backwards and hidden behind the overlay's copies — set their `.opacity(0)` when `mirrored` so only the unmirrored copies show. The geometry to hit: at rest the word starts 16 from the track's outer (left) end; while sliding it ends 16 from the inner (right) end, on the red.

- [ ] **Step 6: `LCDView.swift`**

```swift
import SwiftUI
import SnapCore

struct LCDRow: Identifiable { let id: Strings.Key; let value: String }

/// Three rows; one may be inverted; a sign may stand at the right end of the last row.
struct LCDView: View {
    let rows: [LCDRow]
    let invertedRow: Strings.Key?
    let sign: String?
    let signTwitching: Bool
    let language: Language
    let metrics: Metrics
    let onNameSwipe: (Int) -> Void
    @State private var twitch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                let inverted = row.id == invertedRow
                HStack(alignment: .firstTextBaseline, spacing: metrics.pt(10)) {
                    Text(Strings.t(row.id, language)).font(.system(size: metrics.pt(10), design: .monospaced)).opacity(0.6)
                        .frame(width: metrics.pt(34), alignment: .leading)
                    Text(row.value).font(.system(size: metrics.pt(14), weight: .medium, design: .monospaced)).lineLimit(1)
                    Spacer(minLength: 0)
                    if row.id == .date, let sign {
                        Text(sign).font(.system(size: metrics.pt(12), weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.lcdInk).foregroundStyle(Theme.lcdTop)
                            .offset(x: signTwitching && twitch ? metrics.pt(8) : 0)
                    }
                }
                .padding(.horizontal, metrics.pt(12)).frame(maxWidth: .infinity, minHeight: metrics.lcdHeight / 3)
                .background(inverted ? Theme.lcdInk : .clear)
                .foregroundStyle(inverted ? Theme.lcdTop : Theme.lcdInk)
                .contentShape(Rectangle())
                .gesture(row.id == .name ? DragGesture(minimumDistance: 20).onEnded { g in
                    onNameSwipe(g.translation.width > 0 ? 1 : -1)
                } : nil)
            }
        }
        .frame(height: metrics.lcdHeight)
        .background(LinearGradient(colors: [Theme.lcdTop, Theme.lcdBottom], startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: metrics.pt(5)))
        .overlay(RoundedRectangle(cornerRadius: metrics.pt(5)).stroke(.black.opacity(0.35), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: metrics.pt(7)).stroke(Color(white: 0.05), lineWidth: metrics.pt(4)).padding(-metrics.pt(2)))
        .shadow(color: .white.opacity(0.18), radius: 0, y: 1)
        .onChange(of: signTwitching, initial: true) { _, on in
            guard on else { twitch = false; return }
            withAnimation(.linear(duration: 0).delay(0).repeatForever(autoreverses: false)) {}
            Task { @MainActor in
                while signTwitching {
                    try? await Task.sleep(for: .seconds(1)); twitch = true
                    try? await Task.sleep(for: .seconds(1)); twitch = false
                }
            }
        }
    }
}
```
Implementer's note: the empty `withAnimation` line is a leftover — delete it; the `Task` loop is the twitch (1 s per position, no easing: `twitch` toggles without animation).

- [ ] **Step 7: build.** Expected `BUILD SUCCEEDED`. Unused-view warnings are fine only if none appear as `warning:` lines; fix any.

- [ ] **Step 8: commit** `app: theme, leather, logo, shutter, wheel, slides, LCD`.

---

### Task 9: AppModel and ContentView

**Files:**
- Rewrite: `AfterworkSnap/AppModel.swift`, `AfterworkSnap/ContentView.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–8.
- Produces: the six states of the spec.

- [ ] **Step 1: `AppModel.swift`**

```swift
import SwiftUI
import SnapCore

@Observable @MainActor
final class AppModel {
    enum Phase: Equatable { case live, naming, review, sending, sent, failed }

    let language = Language.from(systemCode: Locale.preferredLanguages.first ?? "en")
    private(set) var phase: Phase = .live
    private(set) var full: Data?            // the capture, uncropped, with its EXIF
    private(set) var fix: (Double, Double)?
    private(set) var names: [String] = []
    private(set) var nameIndex = 0
    private(set) var showIndex = false      // "[n]" and the inverted row, from the first turn on
    private(set) var place: String?
    private(set) var date: String?
    private(set) var sign: String?          // "Post sent." / "SENDING ERROR"
    let camera = SnapSession()
    private let location = LocationSource()
    private var configured = false
    private var namingTask: Task<Void, Never>?

    var shutterLocked: Bool { phase != .live }
    var shutterBreathing: Bool { namingTask != nil }
    var controlsEnabled: Bool { phase == .review || phase == .failed }
    var name: String { names.isEmpty ? nil : names[nameIndex] } ?? (phase == .naming && namingTask != nil ? "…" : Strings.t(.empty, language))
    var nameRow: String { showIndex && !names.isEmpty ? "[\(nameIndex + 1)] \(name)" : name }

    func start() {
        guard !configured else { camera.start(); location.start(); return }
        Secret.seedIfNeeded()
        do { try camera.configure() } catch { return }
        configured = true
        camera.start(); location.start()
    }
    func stop() { camera.stop(); location.stop() }

    func shoot() {
        guard phase == .live else { return }
        let fix = location.usableFix
        camera.capture { [weak self] result in
            guard let self, let data = try? result.get() else { return }
            full = data
            self.fix = fix
            date = TakenDate.from(jpeg: data)
            place = nil
            names = []; nameIndex = 0; showIndex = false; sign = nil
            phase = .naming
            Task { if let fix { place = await location.placeName(for: fix) } }
            fetchNames()
        }
    }

    /// Six names from Claude; the shutter breathes meanwhile.
    func fetchNames() {
        guard let full else { return }
        namingTask?.cancel()
        namingTask = Task {
            let got = await Namer.suggest(for: full, language: language)
            if !Task.isCancelled { names = got; nameIndex = 0 }
            namingTask = nil
            if phase == .naming { phase = .review }
        }
    }

    func step(_ delta: Int) {
        guard !names.isEmpty else { return }
        nameIndex = (nameIndex + delta + names.count) % names.count
        showIndex = true
    }

    func retake() {
        namingTask?.cancel(); namingTask = nil
        full = nil; names = []; sign = nil; phase = .live
    }

    /// One encode with the LCD's name and place; to the library, then to the site.
    func post() {
        guard let full, controlsEnabled else { return }
        phase = .sending
        Task {
            do {
                var extra: [CFString: Any] = [:]
                Metadata.stamp(&extra, name: names.isEmpty ? nil : names[nameIndex], place: place)
                let gps = fix.map { GPSDictionary.make(latitude: $0.0, longitude: $0.1) }
                let square = try SquareCrop.centered(in: full, gps: gps, extra: extra)
                try await PhotoSaver.saveAsFavorite(square)
                try await Uploader.send(square)
                phase = .sent
                sign = Strings.t(.postSent, language)
                self.full = nil; names = []
                try? await Task.sleep(for: .seconds(9))
                if phase == .sent { sign = nil; phase = .live }
            } catch {
                phase = .failed
                sign = Strings.t(.sendingError, language)
            }
        }
    }
}
```
Implementer's note: `var name` above is written as a one-liner that does not compile as intended — write it plainly:
```swift
    var name: String {
        if !names.isEmpty { return names[nameIndex] }
        if phase == .naming && namingTask != nil { return "…" }
        return Strings.t(.empty, language)
    }
```

- [ ] **Step 2: `ContentView.swift`**

```swift
import SwiftUI
import SnapCore

struct ContentView: View {
    @State private var model = AppModel()
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            let m = Metrics(width: geo.size.width)
            let side = geo.size.width * m.side
            let print = geo.size.width - 2 * side
            let lang = model.language
            ZStack(alignment: .top) {
                Leather(metrics: m)
                VStack(spacing: 0) {
                    // title band: just "snap", right-aligned, 3 pt inside the print's right edge
                    Text("snap").font(.system(size: m.pt(17), weight: .semibold)).foregroundStyle(Theme.title(scheme))
                        .frame(maxWidth: .infinity, alignment: .trailing).frame(height: m.titleHeight)
                        .padding(.trailing, side + m.pt(3)).padding(.leading, side)
                        .padding(.top, m.titleTop)
                    // the print
                    ZStack {
                        PreviewView(session: model.camera.session)
                        if let data = model.full, let image = UIImage(data: data) {
                            Image(uiImage: image).resizable().scaledToFill()
                        }
                    }
                    .frame(width: print, height: print)
                    .clipShape(RoundedRectangle(cornerRadius: m.pt(6)))
                    .overlay(RoundedRectangle(cornerRadius: m.pt(6)).stroke(Theme.shade(scheme).opacity(0.35), lineWidth: 1))
                    .overlay(                                                // letterpress: top and left wall in shadow
                        RoundedRectangle(cornerRadius: m.pt(6))
                            .inset(by: 0.5)
                            .stroke(Theme.shade(scheme).opacity(0.45), lineWidth: 3)
                            .blur(radius: 3)
                            .mask(RoundedRectangle(cornerRadius: m.pt(6)))
                            .mask(LinearGradient(colors: [.black, .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .shadow(color: Theme.edgeLight(scheme), radius: 0, y: 1)
                    .padding(.top, m.printTop - m.titleTop - m.titleHeight)
                    LogoView(size: m.logoSize).padding(.top, m.gapLogo)
                    ZStack {
                        ShutterButton(size: m.shutter, locked: model.shutterLocked, breathing: model.shutterBreathing) { model.shoot() }
                        HStack { Spacer()
                            WheelView(size: m.wheel, enabled: model.controlsEnabled, onStep: { model.step($0) }, onCenter: { model.fetchNames() })
                                .padding(.trailing, side)
                        }
                        .offset(y: (m.shutter - m.wheel) / 2 + m.gapLCD - m.pt(12))   // bottom edge 12 above the LCD
                    }
                    .padding(.top, m.gapShutter)
                    LCDView(rows: [LCDRow(id: .name, value: model.nameRow),
                                   LCDRow(id: .loc, value: model.place ?? Strings.t(.empty, lang)),
                                   LCDRow(id: .date, value: model.date ?? Strings.t(.empty, lang))],
                            invertedRow: model.showIndex ? .name : nil,
                            sign: model.sign, signTwitching: model.phase == .failed,
                            language: lang, metrics: m, onNameSwipe: { model.step($0) })
                        .padding(.horizontal, side).padding(.top, m.gapLCD)
                    Spacer(minLength: 0)
                }
                VStack { Spacer()
                    HStack {
                        SlideView(label: Strings.t(.retake, lang), colour: Theme.red, mirrored: true, enabled: model.controlsEnabled, metrics: m) { model.retake() }
                        Spacer()
                        SlideView(label: Strings.t(model.phase == .failed ? .retry : .post, lang), colour: Theme.green, mirrored: false, enabled: model.controlsEnabled, metrics: m) { model.post() }
                    }
                    .padding(.horizontal, side).padding(.bottom, m.slideBottom)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}
```

- [ ] **Step 3: build.** Expected `BUILD SUCCEEDED`, no warnings. Fix what the compiler says without changing behaviour; note every change in the report.

- [ ] **Step 4: commit** `app: the camera back — six states, wheel, slides, LCD, German`.

---

### Task 10: On the phone

**Files:** none new; `ContentView.swift` for the one layout pass.

- [ ] **Step 1:** ⌘R in Xcode-beta on i-16. Check against the mockup (`docs/superpowers/specs/2026-08-30-camera-back-mockup.html` in a browser): positions, sizes, colours in light and dark (toggle in Settings → Display). Adjust constants in `Theme.swift`/`ContentView.swift` until it matches; commit as `ui: from the device`.
- [ ] **Step 2:** A shot: the shutter breathes darkly, locks; within seconds `name` fills, `loc` and `date` are there. Turn the wheel: `[2] …`; swipe the name row: back. Centre: six new.
- [ ] **Step 3:** Slide POST: `Post sent.` for 9 s at the right end of the date row; the shutter unlocks. On the site: the photo with that name and that place; the run log has no `desc for` / `place for` lines; Photos.app has the same file, favorited, with the name in its caption field.
- [ ] **Step 4:** Airplane mode, shoot, POST: `SENDING ERROR` twitching, shutter locked, slide reads RETRY. Airplane off, RETRY: `Post sent.`; one photo on the site.
- [ ] **Step 5:** RETAKE from review: back to live, nothing saved.
- [ ] **Step 6:** iPhone in German (Settings → General → Language & Region → add Deutsch first): labels `name · ort · datum`, `NOCHMAL · POSTEN`, a German name from Claude. Switch back.
- [ ] **Step 7:** iPad if available: same arrangement scaled. Commit any constant changes as `ui: from the iPad`.
- [ ] **Step 8:** Update the spec header: status **built**, and record what was adjusted on the device. Push `snap`, merge to `main`, push.

---

## Self-review against the spec

- Screen constants and colours — Task 8 `Metrics`/`Theme`, Task 9 layout; verified on the device in Task 10.
- Six states, locked shutter, breathing while naming, `Post sent.` 9 s, `SENDING ERROR` twitch — Task 9 `AppModel` + Task 8 views.
- Wheel steps names, centre fetches six, swipe on the name row — Tasks 8, 9.
- Nothing typed — no text fields anywhere.
- Language table — Task 1; applied in Task 9.
- AI: six names, haiku, thumbnail, key via xcconfig — Tasks 4, 5, 7.
- One encode with name/place → library + site — Task 3 + Task 9 `post()`.
- `ingest.sh` reads `ImageDescription` / IPTC `City` — Task 6, with the ImageMagick check and a fallback if IPTC does not round-trip.
- Leather tiles — already in the asset catalog; used in Task 8.
- iPad vertical, scaled — `Metrics`; checked in Task 10.
