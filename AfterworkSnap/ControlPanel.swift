import SwiftUI

/// A recessed dark bezel holding a vertical, knurled thumb-wheel (the
/// camera's top-plate dial, seen edge-on: drag up/down to step through the
/// six suggested names) and the regenerate button (fetch six new names).
struct ControlPanel: View {
    let size: CGFloat            // the panel's height; width is its 4:3
    let enabled: Bool
    let metrics: Metrics
    let onStep: (Int) -> Void    // +1 = next name (drag up), -1 = previous (drag down)
    let onCenter: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var lastTranslation: CGFloat = 0
    @State private var stepAccumulator: CGFloat = 0
    @State private var ridgePhase: CGFloat = 0

    var body: some View {
        let height = size
        let width = size * 4 / 3
        let wheelW = metrics.pt(28)
        let wheelH = height - metrics.pt(12)
        let pitch = metrics.pt(6)

        ZStack {
            RoundedRectangle(cornerRadius: metrics.pt(10))
                .fill(scheme == .dark ? Color(white: 0.16) : Color(white: 0.30))
                .overlay(                                        // inset: a blurred dark stroke inward
                    RoundedRectangle(cornerRadius: metrics.pt(10))
                        .inset(by: metrics.pt(1))
                        .stroke(.black.opacity(0.5), lineWidth: metrics.pt(3))
                        .blur(radius: metrics.pt(2))
                        .clipShape(RoundedRectangle(cornerRadius: metrics.pt(10)))
                )
                .overlay(RoundedRectangle(cornerRadius: metrics.pt(10)).stroke(.black.opacity(0.6), lineWidth: metrics.pt(1)))   // 1 pt darker rim
                .shadow(color: .white.opacity(0.15), radius: 0, y: metrics.pt(1))   // 1 pt lighter line under the bottom edge

            HStack(spacing: 0) {
                thumbWheel(width: wheelW, height: wheelH, pitch: pitch)
                    .gesture(DragGesture(minimumDistance: 2).onChanged { g in
                        guard enabled else { return }
                        // A new gesture that never reached onEnded (e.g. an
                        // interrupted touch) can leave `lastTranslation`
                        // stale; a sudden large drop in magnitude can only
                        // mean this is really a fresh gesture restarting at 0.
                        if abs(g.translation.height) + metrics.pt(20) < abs(lastTranslation) {
                            lastTranslation = 0
                        }
                        let delta = g.translation.height - lastTranslation
                        lastTranslation = g.translation.height
                        ridgePhase += delta
                        stepAccumulator += delta
                        let step = metrics.pt(14)
                        while stepAccumulator <= -step { stepAccumulator += step; onStep(1) }
                        while stepAccumulator >= step { stepAccumulator -= step; onStep(-1) }
                    }.onEnded { _ in lastTranslation = 0; stepAccumulator = 0 })
                    .padding(.leading, metrics.pt(8))
                Spacer(minLength: 0)
                Button(action: { if enabled { onCenter() } }) {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.system(size: metrics.pt(16), weight: .bold))
                        .foregroundStyle(enabled ? Theme.titleBlue : Color(white: 0.48))
                        .frame(width: metrics.pt(40), height: metrics.pt(40))
                        .modifier(Dome(radius: metrics.pt(20)))
                }
                .buttonStyle(.plain)
                .padding(.trailing, metrics.pt(8))
            }
        }
        .frame(width: width, height: height)
        .saturation(enabled ? 1 : 0)
        .brightness(enabled ? 0 : (scheme == .dark ? -0.1 : -0.18))
    }

    /// The knurled dial: horizontal ridges every `pitch`, scrolling with
    /// `ridgePhase` so dragging it looks like it turns.
    private func thumbWheel(width: CGFloat, height: CGFloat, pitch: CGFloat) -> some View {
        let band = pitch / 2
        let cornerRadius = metrics.pt(6)
        return Canvas { context, canvasSize in
            let normalized = ridgePhase.truncatingRemainder(dividingBy: pitch)
            var y = normalized >= 0 ? normalized - pitch : normalized
            while y < canvasSize.height {
                context.fill(Path(CGRect(x: 0, y: y, width: canvasSize.width, height: band)), with: .color(Color(white: 0.55)))
                context.fill(Path(CGRect(x: 0, y: y + band, width: canvasSize.width, height: band)), with: .color(Color(white: 0.28)))
                y += pitch
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(LinearGradient(colors: [.white.opacity(0.25), .clear, .black.opacity(0.2)], startPoint: .top, endPoint: .bottom))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(.black.opacity(0.6), lineWidth: metrics.pt(1)))
    }
}
