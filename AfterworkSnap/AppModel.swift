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
    var name: String {
        if !names.isEmpty { return names[nameIndex] }
        if phase == .naming && namingTask != nil { return "…" }
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
            Task { if let fix { self.place = await self.location.placeName(for: fix) } }
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
