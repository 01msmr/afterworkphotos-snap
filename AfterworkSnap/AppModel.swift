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
    private var configured = false
    private var capturing = false
    private var namingTask: Task<Void, Never>?
    private var placeTask: Task<Void, Never>?
    private var fetchID = 0
    private var saved = false               // already in the library — a retry must not add it twice
    private var placeDone = false           // the place lookup for this shot has finished (or there is none)

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
        Secret.seedIfNeeded()
        do { try camera.configure() } catch { return }
        configured = true
        camera.onDidStartRunning = { [weak self] in
            Task { @MainActor in self?.isLive = true }
        }
        camera.start(); location.start()
    }
    func stop() { camera.stop(); location.stop() }

    func shoot() {
        guard !shutterLocked else { return }
        sign = nil
        capturing = true
        camera.freezePreview(true)                 // instant still, until retake or a finished post
        let fix = location.usableFix
        camera.capture { [weak self] result in
            guard let self else { return }
            capturing = false
            guard let data = try? result.get() else { camera.freezePreview(false); return }
            full = data
            preview = UIImage(data: data)
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
            namingTask = nil
            naming = false
            if phase == .naming { phase = .review }
        }
    }

    func step(_ delta: Int) {
        guard !names.isEmpty else { return }
        nameIndex = (nameIndex + delta + names.count) % names.count
        showIndex = true
    }

    func retake() {
        namingTask?.cancel(); namingTask = nil; naming = false
        placeTask?.cancel(); placeTask = nil
        camera.freezePreview(false)
        full = nil; preview = nil; names = []; sign = nil; phase = .live
        place = nil; date = nil; nameIndex = 0; showIndex = false
        saved = false
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
                let square = try SquareCrop.centered(in: full, gps: gps, extra: extra)
                if !saved {
                    try await PhotoSaver.saveAsFavorite(square)
                    saved = true
                }
                try await Uploader.send(square)
                phase = .sent
                sign = Strings.t(.postSent, language)
                camera.freezePreview(false)
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
