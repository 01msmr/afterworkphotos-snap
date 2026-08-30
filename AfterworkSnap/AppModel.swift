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
    let camera = SnapSession()
    private let location = LocationSource()
    private var configured = false
    private var capturing = false
    private var namingTask: Task<Void, Never>?
    private var placeTask: Task<Void, Never>?
    private var fetchID = 0
    private var saved = false               // already in the library — a retry must not add it twice
    private var encoded: Data?              // the one encode, reused verbatim on retry

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
        camera.start(); location.start()
    }
    func stop() { camera.stop(); location.stop() }

    func shoot() {
        guard !shutterLocked else { return }
        sign = nil
        capturing = true
        let fix = location.usableFix
        camera.capture { [weak self] result in
            guard let self else { return }
            capturing = false
            guard let data = try? result.get() else { return }
            full = data
            preview = UIImage(data: data)
            self.fix = fix
            date = TakenDate.from(jpeg: data)
            place = nil
            names = []; nameIndex = 0; showIndex = false
            saved = false; encoded = nil
            phase = .naming
            placeTask?.cancel()
            placeTask = Task { [weak self] in
                guard let self, let fix else { return }
                self.place = await self.location.placeName(for: fix)
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
            guard myID == fetchID else { return }   // superseded: do nothing
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
        full = nil; preview = nil; names = []; sign = nil; phase = .live
        place = nil; date = nil; nameIndex = 0; showIndex = false
        saved = false; encoded = nil
    }

    /// One encode with the LCD's name and place; to the library, then to the
    /// site. A retry (after `.failed`) reuses the same encoded bytes and
    /// skips the library save if that already succeeded.
    func post() {
        guard let full, controlsEnabled else { return }
        namingTask?.cancel(); namingTask = nil; naming = false
        phase = .sending
        Task {
            if place == nil, let fix {
                let loc = location
                place = await withTaskGroup(of: String?.self) { group in
                    group.addTask { await loc.placeName(for: fix) }
                    group.addTask { try? await Task.sleep(for: .seconds(3)); return nil }
                    let result = await group.next() ?? nil
                    group.cancelAll()
                    return result
                }
            }
            do {
                let square: Data
                if let encoded {
                    square = encoded
                } else {
                    var extra: [CFString: Any] = [:]
                    Metadata.stamp(&extra, name: names.isEmpty ? nil : names[nameIndex], place: place)
                    let gps = fix.map { GPSDictionary.make(latitude: $0.0, longitude: $0.1) }
                    let made = try SquareCrop.centered(in: full, gps: gps, extra: extra)
                    encoded = made
                    square = made
                }
                if !saved {
                    try await PhotoSaver.saveAsFavorite(square)
                    saved = true
                }
                try await Uploader.send(square)
                phase = .sent
                sign = Strings.t(.postSent, language)
                self.full = nil; self.preview = nil; names = []
                place = nil; date = nil; nameIndex = 0; showIndex = false
                saved = false; encoded = nil
                try? await Task.sleep(for: .seconds(9))
                if phase == .sent { sign = nil; phase = .live }
            } catch {
                phase = .failed
                sign = Strings.t(.sendingError, language)
            }
        }
    }
}
