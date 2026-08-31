import CoreHaptics
import UIKit

/// The mechanical click of the release, played through CoreHaptics.
///
/// Going in: the dome switch bottoms out — one sharp snap, then its tiny
/// rebound 12 ms later (a real click is never a single impulse; the
/// second, softer transient is what makes it read as metal-on-metal
/// rather than a phone buzz). Coming back out: a single lighter tick,
/// the spring returning the disc. Falls back to a rigid
/// `UIImpactFeedbackGenerator` where the haptic engine is unavailable.
final class ShutterHaptics {
    static let shared = ShutterHaptics()
    private var engine: CHHapticEngine?
    private let fallback = UIImpactFeedbackGenerator(style: .rigid)

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        engine?.isAutoShutdownEnabled = true
    }

    /// Spins the engine up ahead of the first press, so the first click
    /// isn't late.
    func prepare() { try? engine?.start(); fallback.prepare() }

    func press() {
        play([
            transient(at: 0,     intensity: 1.0,  sharpness: 1.0),
            transient(at: 0.012, intensity: 0.35, sharpness: 0.5),
        ], fallbackIntensity: 1.0)
    }

    func release() {
        play([transient(at: 0, intensity: 0.5, sharpness: 0.8)], fallbackIntensity: 0.55)
    }

    /// A locked button doesn't travel: no snap, no rebound — a dead,
    /// dull double-knock, like rapping a bolted door.
    func locked() {
        play([
            transient(at: 0,    intensity: 0.6, sharpness: 0.15),
            transient(at: 0.06, intensity: 0.5, sharpness: 0.10),
        ], fallbackIntensity: 0.5)
    }

    private func transient(at t: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: t)
    }

    private func play(_ events: [CHHapticEvent], fallbackIntensity: CGFloat) {
        guard let engine,
              let pattern = try? CHHapticPattern(events: events, parameters: []),
              let player = try? engine.makePlayer(with: pattern),
              (try? engine.start()) != nil
        else { fallback.impactOccurred(intensity: fallbackIntensity); return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }
}
