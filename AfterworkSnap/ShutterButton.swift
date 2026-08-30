import SwiftUI

/// The red release: flat, iOS 26 glass style — not domed.
///
/// `locked`'s "dimmed" look is both a flat colour swap AND a filter, so
/// the difference from unlocked is obvious at a glance: the base is drawn
/// in `Theme.redDark` when locked, `Theme.shutterMid` otherwise, and a
/// `.saturation(0.6)`/`.brightness(-0.08)` filter sits on top while
/// locked. While `breathing`, the *other* colour pulses on top of the
/// base — inverted when locked (starts fully opaque and fades to 0, so a
/// fresh tap still reads bright red for an instant before settling into
/// the breathing dark). Unlocked is the full base red with the glass,
/// unfiltered.
struct ShutterButton: View {
    let size: CGFloat
    let metrics: Metrics
    let locked: Bool
    let breathing: Bool
    let action: () -> Void
    @State private var lit = false

    private var restColour: Color { locked ? Theme.redDark : Theme.shutterMid }
    private var pulseColour: Color { locked ? Theme.shutterMid : Theme.redDark }

    /// `opaque`: the flat fallback needs a fully opaque rest colour; under
    /// the iOS 26 glass effect a mostly-opaque base keeps it reading as
    /// red rather than washed-out pink, while the tinted glass still shows.
    private func base(opaque: Bool) -> some View {
        ZStack {
            Circle().fill(restColour.opacity(opaque ? 1 : 0.85))
            Circle().fill(pulseColour)
                .opacity(locked ? (lit ? 0 : 1) : (lit ? 1 : 0))
                .animation(breathing ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true) : .linear(duration: 0.2), value: lit)
        }
    }

    var body: some View {
        let s = metrics.scale
        Button(action: { if !locked { action() } }) {
            Group {
                if #available(iOS 26, *) {
                    // Liquid Glass: a clear (not regular) glass, lightly
                    // tinted with the current rest colour, over an already
                    // mostly-opaque base — a clearly red, flat, glassy
                    // disc, not translucent pink.
                    base(opaque: false)
                        .glassEffect(.clear.tint(restColour.opacity(0.5)).interactive(), in: .circle)
                        .overlay(
                            Circle().fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.4)))
                        )
                } else {
                    base(opaque: true)
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1 * s))
                        .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 1 * s))
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 6 * s, y: 3 * s)
            .saturation(locked ? 0.6 : 1)
            .brightness(locked ? -0.08 : 0)
        }
        .buttonStyle(.plain)
        .frame(width: size, height: size)
        .onChange(of: breathing, initial: true) { _, on in
            lit = on
        }
    }
}
