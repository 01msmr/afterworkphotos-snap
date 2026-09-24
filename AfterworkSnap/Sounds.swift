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
        var names = ["tick", "crunch", "shutter", "step", "eject", "knock", "zip"]   // + "tchack" and "thup" stay shelved in Sounds/, unloaded
        for pitched in ["step", "tick"] { names += (0..<5).map { "\(pitched)_p\($0)" } }   // five pre-pitched variants each — see play(_:speed:)
        for name in names {
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
    /// Ratchet ticks at mechanism speed: picks one of the five
    /// pre-pitched variants (`name_p0` … `name_p4`, 0.85x to 1.5x) by
    /// normalized speed 0…1 — driving the gear faster raises its pitch.
    static func play(_ name: String, speed: Double) {
        play("\(name)_p\(min(4, max(0, Int(speed * 5))))")
    }

    /// Playback hops onto its own queue — `AVAudioPlayer.play()` can
    /// block for a few ms, which is a visible hitch mid-gesture.
    private static let playQueue = DispatchQueue(label: "snap.sounds")
    static func play(_ name: String) {
        playQueue.async {
            guard let player = players[name] else { return }
            player.currentTime = 0
            player.play()
        }
    }

    /// Cuts a playing sound short with a few-ms fade, so it ends without
    /// a click; the volume is restored for the next play.
    static func stop(_ name: String) {
        playQueue.async {
            guard let player = players[name], player.isPlaying else { return }
            player.setVolume(0, fadeDuration: 0.03)
            playQueue.asyncAfter(deadline: .now() + 0.03) {
                player.stop()
                player.volume = 1
            }
        }
    }

    /// Wakes the audio hardware when the shutter or the Upload button is
    /// pressed, so the sounds that follow (the shutter's, the eject)
    /// start at once instead of waiting for it. Off the main thread —
    /// `setActive` can block. The category stays whatever is set.
    static func wake() {
        playQueue.async {
            try? AVAudioSession.sharedInstance().setActive(true)
            players["eject"]?.prepareToPlay()
        }
    }

    /// Plays, then calls `audible` on the main actor once the sound is
    /// actually coming out — after `play()` has started it, plus the
    /// route's output latency (a few ms on the speaker, far more over
    /// Bluetooth). For motion that must move with its sound.
    static func play(_ name: String, audible: @escaping @MainActor () -> Void) {
        playQueue.async {
            if let player = players[name] {
                player.currentTime = 0
                player.play()
            }
            let latency = AVAudioSession.sharedInstance().outputLatency
            DispatchQueue.main.asyncAfter(deadline: .now() + latency) {
                MainActor.assumeIsolated { audible() }
            }
        }
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
