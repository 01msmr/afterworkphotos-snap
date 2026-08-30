import SwiftUI
import UIKit

/// A recessed dark bezel holding a vertical, knurled thumb-wheel (the
/// camera's top-plate dial, seen edge-on: drag to step through the six
/// suggested names, with a haptic detent per step) and the regenerate
/// button (fetch six new names).
struct ControlPanel: View {
    let size: CGFloat            // the panel's height; width is its 4:3
    let enabled: Bool
    let metrics: Metrics
    let onStep: (Int) -> Bool    // +1 = next name (drag down), -1 = previous (drag up); returns whether it moved
    let onCenter: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var lastTranslation: CGFloat = 0
    @State private var stepAccumulator: CGFloat = 0
    @State private var ridgePhase: CGFloat = 0
    @State private var dragActive = false
    @State private var haptic = UISelectionFeedbackGenerator()

    var body: some View {
        let height = size
        let width = size * 4 / 3
        let wheelW = metrics.pt(28)
        let wheelH = height - metrics.pt(12)
        let pitch = metrics.pt(4)

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
                    .gesture(DragGesture(minimumDistance: 2)
                        .onChanged { g in
                            guard enabled else { return }
                            if !dragActive { dragActive = true; haptic.prepare() }
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
                            while stepAccumulator >= step { stepAccumulator -= step; if onStep(1) { haptic.selectionChanged() } }
                            while stepAccumulator <= -step { stepAccumulator += step; if onStep(-1) { haptic.selectionChanged() } }
                        }
                        .onEnded { _ in
                            dragActive = false
                            lastTranslation = 0; stepAccumulator = 0
                            withAnimation(.spring(duration: 0.15)) {
                                ridgePhase = (ridgePhase / pitch).rounded() * pitch
                            }
                        })
                    .padding(.leading, metrics.pt(8))
                Spacer(minLength: 0)
                Button(action: { if enabled { onCenter() } }) {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.system(size: metrics.pt(16), weight: .bold))
                        .foregroundStyle(enabled ? (scheme == .dark ? Theme.titleBlueDark : Theme.titleBlue) : Color(white: 0.48))
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

    /// The knurled dial, seen edge-on: a cylinder's horizontal shading
    /// (dark at the edges, lit in the centre), with fine ridges drawn over
    /// it and scrolling with `ridgePhase`; the ridges' own alpha is
    /// multiplied by that same shading (via `.mask`), so they read as
    /// brighter in the centre and fade toward the edges, like a real
    /// knurled surface. Rounded top/bottom ends (corner radius = half width).
    private func thumbWheel(width: CGFloat, height: CGFloat, pitch: CGFloat) -> some View {
        let band = pitch / 2
        let cornerRadius = width / 2
        let edgeShade = scheme == .dark ? 0.12 : 0.25
        let centreShade = scheme == .dark ? 0.45 : 0.72
        let cylinderShade = LinearGradient(colors: [Color(white: edgeShade), Color(white: centreShade), Color(white: edgeShade)],
                                           startPoint: .leading, endPoint: .trailing)
        return ZStack {
            Rectangle().fill(cylinderShade)
            Canvas { context, canvasSize in
                let normalized = ridgePhase.truncatingRemainder(dividingBy: pitch)
                var y = normalized >= 0 ? normalized - pitch : normalized
                while y < canvasSize.height {
                    context.fill(Path(CGRect(x: 0, y: y, width: canvasSize.width, height: band)), with: .color(Color(white: 0.28)))
                    context.fill(Path(CGRect(x: 0, y: y + band, width: canvasSize.width, height: band)), with: .color(Color(white: 0.55)))
                    y += pitch
                }
            }
            .mask(cylinderShade)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(.black.opacity(0.6), lineWidth: metrics.pt(1)))
    }
}
