import SwiftUI

/// The red release. `breathing`: the dark layer fades in and out, 1.6 s each
/// way. `locked`: greyed and inert.
struct ShutterButton: View {
    let size: CGFloat
    let metrics: Metrics
    let locked: Bool
    let breathing: Bool
    let action: () -> Void
    @State private var lit = false

    var body: some View {
        let s = metrics.scale
        Button(action: { if !locked { action() } }) {
            ZStack {
                Circle().fill(RadialGradient(colors: [Theme.shutterTop, Theme.shutterMid, Theme.shutterEdge],
                                             center: UnitPoint(x: 0.4, y: 0.32), startRadius: 0, endRadius: size * 0.6))
                Circle().fill(RadialGradient(colors: [Theme.breathTop, Theme.breathEdge],
                                             center: UnitPoint(x: 0.4, y: 0.32), startRadius: 0, endRadius: size * 0.6))
                    .opacity(lit ? 1 : 0)
                    .animation(breathing ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true) : .linear(duration: 0.2), value: lit)
                Circle().strokeBorder(.white.opacity(0.45), lineWidth: 3 * s).padding(1 * s).mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
            }
            .overlay(Circle().stroke(Color(red: 0.35, green: 0.01, blue: 0), lineWidth: 1 * s))
            .overlay(Circle().stroke(.black.opacity(0.2), lineWidth: 7 * s).padding(-7 * s))    // the ridged collar
            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1 * s).padding(-8 * s))
            .shadow(color: .black.opacity(0.4), radius: 3 * s, y: 4 * s)
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
