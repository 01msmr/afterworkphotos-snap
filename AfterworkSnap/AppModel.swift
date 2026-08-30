import SwiftUI
import SnapCore

@Observable @MainActor
final class AppModel {
    enum Phase: Equatable { case live, naming, review, sending, sent, failed }

    let language = Language.from(systemCode: Locale.preferredLanguages.first ?? "en")
    private(set) var phase: Phase = .live
    private(set) var full: Data?            // the capture, uncropped, with its EXIF
    private(set) var preview: UIImage?      // decoded once, shown until retake or a finished post
    private(set) var fix: (Double, Double)?
    private(set) var names: [String] = []
    private(set) var nameIndex = 0
    private(set) var showIndex = false      // "[n]" and the inverted row, from the first turn on
    private(set) var place: String?
    private(set) var date: String?
    private(set) var sign: String?          // "Post sent." / "SENDING ERROR"
    private(set) var naming = false         // true from fetchNames() start until this fetch lands
    private(set) var isLive = false          // the session has started running
    let camera = SnapSession()
    private let location = LocationSource()
    private let voiceTrigger = VoiceTrigger()
    private var configured = false
    private var capturing = false
    private var namingTask: Task<Void, Never>?
    private var placeTask: Task<Void, Never>?
    private var fetchID = 0
    private var saved = false               // already in the library — a retry must not add it twice
    private var placeDone = false           // the place lookup for this shot has finished (or there is none)
    private var previewTask: Task<Void, Never>?   // decodes `preview`; cancelled on retake/post-success
#if DEBUG
    private let launchTime = Date()          // for the one-line startup timing print below
#endif

    var shutterLocked: Bool { capturing || (phase != .live && phase != .sent) }
    var shutterBreathing: Bool { naming }
    var controlsEnabled: Bool { phase == .naming || phase == .review || phase == .failed }
    var name: String {
        if !names.isEmpty { return names[nameIndex] }
        if phase == .naming && naming { return "…" }
        return Strings.t(.empty, language)
    }
    var nameRow: String { showIndex && !names.isEmpty ? "[\(nameIndex + 1)] \(name)" : name }

    func start() {
        guard !configured else { camera.start(); location.start(); return }
        voiceTrigger.onTrigger = { [weak self] in self?.shoot() }
        camera.onDidStartRunning = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.isLive = true
                #if DEBUG
                print("launch → isLive: \(Int(Date().timeIntervalSince(self.launchTime) * 1000)) ms")
                #endif
                if self.phase == .live { self.voiceTrigger.start() }
            }
        }
        // Off the main thread: configure() and startRunning() are both
        // blocking AVFoundation calls. Kick this off first, then the rest.
        // `configured` only becomes true once that has actually succeeded.
        camera.configureAndStart { [weak self] error in
            guard let self else { return }
            Task { @MainActor in if error == nil { self.configured = true } }
        }
        Secret.seedIfNeeded()
        location.start()
    }
    func stop() { camera.stop(); location.stop(); voiceTrigger.stop() }

    func shoot() {
        guard !shutterLocked else { return }
        sign = nil
        capturing = true
        voiceTrigger.stop()
        camera.freezePreview(true)                 // instant still, until retake or a finished post
        let fix = location.usableFix
        camera.capture { [weak self] result in
            guard let self else { return }
            capturing = false
            guard let data = try? result.get() else { camera.freezePreview(false); return }
            full = data
            self.fix = fix
            date = TakenDate.from(jpeg: data)
            place = nil
            names = []; nameIndex = 0; showIndex = false
            saved = false
            phase = .naming
            placeTask?.cancel()
            if let fix {
                placeDone = false
                placeTask = Task { [weak self] in
                    guard let self else { return }
                    let name = await self.location.placeName(for: fix)
                    guard !Task.isCancelled else { return }
                    self.place = name
                    self.placeDone = true
                }
            } else {
                placeTask = nil
                placeDone = true
            }
            fetchNames()
            previewTask?.cancel()
            previewTask = Task { [weak self] in
                let image = await Task.detached(priority: .userInitiated) { UIImage(data: data) }.value
                guard !Task.isCancelled else { return }
                self?.preview = image
            }
        }
    }

    /// Six names from Claude; the shutter breathes meanwhile. A later call
    /// (the wheel's centre button) supersedes an in-flight one — the stale
    /// fetch's answer, whenever it lands, is discarded.
    func fetchNames() {
        guard let full else { return }
        namingTask?.cancel()
        fetchID += 1
        let myID = fetchID
        naming = true
        namingTask = Task {
            let got = await Namer.suggest(for: full, language: language)
            guard myID == fetchID, !Task.isCancelled else { return }   // superseded or cancelled: do nothing
            names = got; nameIndex = 0
            showIndex = true   // "[1] <name>" inverted at once, not just after the first manual step
            namingTask = nil
            naming = false
            if phase == .naming { phase = .review }
        }
    }

    /// Clamped, not wrapped: at either end, further steps do nothing.
    /// Returns whether the index actually moved, so a caller (the wheel)
    /// knows whether this step earned a haptic tick.
    @discardableResult
    func step(_ delta: Int) -> Bool {
        guard !names.isEmpty else { return false }
        let clamped = min(max(nameIndex + delta, 0), names.count - 1)
        guard clamped != nameIndex else { return false }
        nameIndex = clamped
        showIndex = true
        return true
    }

    /// The drum's own selection — sets the index directly (clamped) rather
    /// than by a relative delta.
    func select(_ i: Int) {
        guard !names.isEmpty else { return }
        let clamped = min(max(i, 0), names.count - 1)
        guard clamped != nameIndex else { return }
        nameIndex = clamped
        showIndex = true
    }

    func retake() {
        namingTask?.cancel(); namingTask = nil; naming = false
        fetchID += 1   // a late (cooperatively-cancelled but not-yet-resumed) fetch must not land after this
        placeTask?.cancel(); placeTask = nil
        previewTask?.cancel(); previewTask = nil
        camera.freezePreview(false)
        full = nil; preview = nil; names = []; sign = nil; phase = .live
        place = nil; date = nil; nameIndex = 0; showIndex = false
        saved = false
        voiceTrigger.start()
    }

    /// A fresh encode with the LCD's current name and place; to the
    /// library once, then to the site every time (a retry after `.failed`
    /// re-encodes with whatever the LCD shows now — the site always gets
    /// the current name; the library copy, saved only on the first
    /// attempt, keeps whichever name was current then).
    func post() {
        guard let full, controlsEnabled else { return }
        namingTask?.cancel(); namingTask = nil; naming = false
        phase = .sending
        Task {
            // Bounded poll, not a race: the bridged CLGeocoder call can't
            // actually be cancelled, so this only bounds our own wait —
            // whatever `place` holds once `placeDone` (or the 3 s cap) is
            // what ships.
            var waited = 0
            while !placeDone && waited < 30 {
                try? await Task.sleep(for: .milliseconds(100))
                waited += 1
            }
            do {
                var extra: [CFString: Any] = [:]
                Metadata.stamp(&extra, name: names.isEmpty ? nil : names[nameIndex], place: place)
                let gps = fix.map { GPSDictionary.make(latitude: $0.0, longitude: $0.1) }
                let square = try await Task.detached(priority: .userInitiated) {
                    try SquareCrop.centered(in: full, gps: gps, extra: extra)
                }.value
                if !saved {
                    try await PhotoSaver.saveAsFavorite(square)
                    saved = true
                }
                try await Uploader.send(square)
                phase = .sent
                sign = Strings.t(.postSent, language)
                voiceTrigger.start()   // the shutter itself unlocks at .sent too — listen again from here
                camera.freezePreview(false)
                previewTask?.cancel(); previewTask = nil
                self.full = nil; self.preview = nil; names = []
                place = nil; date = nil; nameIndex = 0; showIndex = false
                saved = false
                try? await Task.sleep(for: .seconds(9))
                if phase == .sent { sign = nil; phase = .live }
            } catch {
                phase = .failed
                sign = Strings.t(.sendingError, language)
            }
        }
    }
}
