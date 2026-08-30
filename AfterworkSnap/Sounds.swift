import Foundation
import AudioToolbox

/// Short UI sound effects — tick, post, crunch — played from the WAV
/// files bundled under `Sounds/`. `AudioServicesPlaySystemSound` is a
/// short, fire-and-forget playback call: it doesn't configure or
/// activate any `AVAudioSession` category of its own, so it plays fine
/// alongside `VoiceTrigger`'s own `.playAndRecord` session. Volume is
/// baked into the files, not adjusted here.
enum Sounds {
    private static var ids: [String: SystemSoundID] = [:]

    static func play(_ name: String) {
        if let id = ids[name] {
            AudioServicesPlaySystemSound(id)
            return
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        var id: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError else { return }
        ids[name] = id
        AudioServicesPlaySystemSound(id)
    }

    /// A well-known built-in system sound (no bundled file, no caching
    /// needed — the OS already owns these). Used for the post-success
    /// "mail sent" whoosh, ID 1001.
    static func playSystem(_ id: SystemSoundID) {
        AudioServicesPlaySystemSound(id)
    }
}
