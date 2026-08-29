import SwiftUI
import SnapCore

@Observable @MainActor
final class AppModel {
    enum Phase: Equatable {
        case live
        case review(hasPlace: Bool)
        case saving
        case sending
        case failed(String)          // stays on review; confirm becomes retry
        case sent
    }

    private(set) var phase: Phase = .live
    private(set) var square: Data?
    let camera = SnapSession()
    private let location = LocationSource()
    private var saved = false

    func start() {
        Secret.seedIfNeeded()
        do { try camera.configure() } catch { phase = .failed(error.localizedDescription); return }
        camera.start()
        location.start()
    }

    func stop() { camera.stop(); location.stop() }

    func shoot() {
        guard phase == .live else { return }
        let fix = location.usableFix
        camera.capture { [weak self] result in
            guard let self else { return }
            do {
                let full = try result.get()
                let gps = fix.map { GPSDictionary.make(latitude: $0.0, longitude: $0.1) }
                square = try SquareCrop.centered(in: full, gps: gps)
                saved = false
                phase = .review(hasPlace: fix != nil)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func discard() {
        square = nil
        saved = false
        phase = .live
    }

    /// Save to the library first, then send. A retry skips the save if it
    /// already succeeded.
    func confirm() {
        guard let square else { return }
        Task {
            if !saved {
                phase = .saving
                do { try await PhotoSaver.saveAsFavorite(square); saved = true }
                catch { phase = .failed(error.localizedDescription); return }
            }
            phase = .sending
            do { try await Uploader.send(square) }
            catch { phase = .failed("Saved — not sent. \(error.localizedDescription)"); return }
            phase = .sent
            try? await Task.sleep(for: .seconds(1))
            if phase == .sent { discard() }
        }
    }

    var hasPlace: Bool {
        if case .review(let has) = phase { return has }
        return true
    }
}
