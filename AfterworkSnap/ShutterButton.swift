import SwiftUI

/// The red release: flat, iOS 26 glass style — not domed. `breathing`: the
/// dark layer fades in and out, 1.6 s each way. `locked`: greyed and inert.
struct ShutterButton: View {
    let size: CGFloat
    let metrics: Metrics
    let locked: Bool
    let breathing: Bool
    let action: () -> Void
    @State private var lit = false

    /// `opaque`: the flat fallback needs a fully opaque red; under the
    /// iOS 26 glass effect a translucent base lets the tint/highlights show.
    private func base(opaque: Bool) -> some View {
        ZStack {
            Circle().fill(Theme.shutterMid.opacity(opaque ? 1 : 0.35))
            Circle().fill(Theme.breathTop)
                .opacity(lit ? 1 : 0)
                .animation(breathing ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true) : .linear(duration: 0.2), value: lit)
        }
    }

    var body: some View {
        let s = metrics.scale
        Button(action: { if !locked { action() } }) {
            Group {
                if #available(iOS 26, *) {
                    // Liquid Glass: a translucent, tinted base under the
                    // effect, no hard ring — just a soft top highlight.
                    base(opaque: false)
                        .glassEffect(.regular.tint(Theme.shutterMid.opacity(0.85)).interactive(), in: .circle)
                        .overlay(
                            Circle().fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                        )
                } else {
                    base(opaque: true)
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1 * s))
                        .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 1 * s))
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 6 * s, y: 3 * s)
            .saturation(locked ? 0.25 : 1)
            .brightness(locked ? -0.25 : 0)
        }
        .buttonStyle(.plain)
        .frame(width: size, height: size)
        .onChange(of: breathing, initial: true) { _, on in
            lit = on
        }
    }
}
