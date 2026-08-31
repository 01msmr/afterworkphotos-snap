import Foundation
import AVFoundation
import AudioToolbox

/// Short UI sound effects — the bundled WAVs (see the preload list) and the post
/// whoosh (a built-in system sound). Tick/crunch go through `AVAudioPlayer`
/// rather than `AudioServicesPlaySystemSound`, specifically so they follow
/// `AVAudioSession`'s active route (e.g. connected Bluetooth headphones)
/// instead of always playing on the speaker — `AudioServicesPlaySystemSound`
/// does not respect session routing the same way a real player does.
enum Sounds {
    /// One `AVAudioPlayer` per bundled sound, preloaded and prepared once
    /// (on first reference to `Sounds`), not re-created per play.
    private static let players: [String: AVAudioPlayer] = {
        var result: [String: AVAudioPlayer] = [:]
        for name in ["tick", "crunch", "shutter", "tchack", "eject", "thup", "knock", "zip"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds")
                ?? Bundle.main.url(forResource: name, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            result[name] = player
        }
        return result
    }()

    /// Builds every player (the lazy `players` map) ahead of time, so
    /// the first tick mid-gesture doesn't pay for loading all the WAVs
    /// on the main thread. Call early, off the main thread.
    static func preload() { _ = players }

    /// Plays a bundled sound from the preload list — safe to call from
    /// the main actor or `VoiceTrigger`'s own audio queue.
    static func play(_ name: String) {
        guard let player = players[name] else { return }
        player.currentTime = 0
        player.play()
    }

    /// A well-known built-in system sound — no bundled file, no
    /// `AVAudioPlayer` needed. Used for the post-success "mail sent"
    /// whoosh, ID 1001. Kept as `AudioServicesPlaySystemSound` per the
    /// controller's ruling even though, like tick/crunch used to, it
    /// plays on the speaker regardless of a connected Bluetooth route —
    /// see the fix report for the rationale.
    static func playSystem(_ id: SystemSoundID) {
        AudioServicesPlaySystemSound(id)
    }
}
