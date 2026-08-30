import SwiftUI

struct WheelView: View {
    let size: CGFloat
    let enabled: Bool
    let onStep: (Int) -> Void      // +1 clockwise, -1 counter-clockwise
    let onCenter: () -> Void
    @State private var lastAngle: Double?
    @State private var accumulated: Double = 0
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let centre = size * (42.0 / 72.0)   // the spec's "size - 30" at the reference 72 pt wheel, scaled with size
        ZStack {
            Circle().fill(AngularGradient(colors: Array(repeating: [Color(white: scheme == .dark ? 0.3 : 0.85), Color(white: scheme == .dark ? 0.12 : 0.66)], count: 45).flatMap { $0 }, center: .center))
                .overlay(Circle().strokeBorder(Color(white: scheme == .dark ? 0.2 : 0.76), lineWidth: 6))
                .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 3)
                .gesture(DragGesture(minimumDistance: 2).onChanged { g in
                    guard enabled else { return }
                    let c = CGPoint(x: size / 2, y: size / 2)
                    let a = atan2(g.location.y - c.y, g.location.x - c.x)
                    if let last = lastAngle {
                        var d = a - last
                        if d > .pi { d -= 2 * .pi } else if d < -.pi { d += 2 * .pi }
                        accumulated += d
                        let step = Double.pi / 6
                        while accumulated >= step { accumulated -= step; onStep(1) }
                        while accumulated <= -step { accumulated += step; onStep(-1) }
                    }
                    lastAngle = a
                }.onEnded { _ in lastAngle = nil; accumulated = 0 })
            Button(action: { if enabled { onCenter() } }) {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")   // the rotate-arrows glyph
                    .font(.system(size: size * 0.22, weight: .bold))
                    .foregroundStyle(enabled ? Color(white: 0.45) : Color(white: 0.6))
                    .frame(width: centre, height: centre)
                    .modifier(Dome(radius: centre / 2))
            }
            .buttonStyle(.plain)
        }
        .frame(width: size, height: size)
        .saturation(enabled ? 1 : 0)
        .brightness(enabled ? 0 : (scheme == .dark ? -0.1 : -0.18))
    }
}
