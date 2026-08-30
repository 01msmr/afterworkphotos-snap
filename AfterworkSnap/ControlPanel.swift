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
        let wheelW = metrics.pt(40)
        let wheelH = height - metrics.pt(12)
        let pitch = metrics.pt(3.5)

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
                            // Reset only when a new gesture actually begins —
                            // `dragActive` (not a magnitude heuristic) is the guard.
                            if !dragActive {
                                dragActive = true
                                haptic.prepare()
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
                        .frame(width: metrics.pt(36), height: metrics.pt(36))
                        .modifier(Dome(radius: metrics.pt(18)))
                }
                .buttonStyle(.plain)
                .padding(.trailing, metrics.pt(8))
            }
        }
        .frame(width: width, height: height)
        .saturation(enabled ? 1 : 0)
        .brightness(enabled ? 0 : (scheme == .dark ? -0.1 : -0.18))
    }

    /// The knurled dial, seen edge-on: everything — the cylinder's own
    /// horizontal shading and the scrolling ridges over it — is drawn in a
    /// single `Canvas`, no `.mask` (a mask over an already-opaque `Color`
    /// fill is a no-op, which is why round 6/7's version rendered as flat
    /// lines instead of a shaded dial). Each ridge band is itself filled
    /// with the same left→centre→right gradient profile, at the band's
    /// own colour and alpha, so the bands read strongly at the horizontal
    /// centre and fade to nearly flat at the edges — a cylinder, not a
    /// striped rectangle.
    private func thumbWheel(width: CGFloat, height: CGFloat, pitch: CGFloat) -> some View {
        let isDark = scheme == .dark
        let edgeShade = isDark ? 0.10 : 0.22
        let centreShade = isDark ? 0.50 : 0.78
        let darkBand = metrics.pt(1.5)
        let lightBand = metrics.pt(2)

        return Canvas { context, size in
            let start = CGPoint(x: 0, y: 0)
            let end = CGPoint(x: size.width, y: 0)

            // (a) the cylinder itself: one horizontal gradient across the whole capsule.
            let baseGradient = Gradient(colors: [Color(white: edgeShade), Color(white: centreShade), Color(white: edgeShade)])
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(baseGradient, startPoint: start, endPoint: end))

            // (b) ridges: dark and light bands, each its own left→centre→right alpha profile.
            let darkGradient = Gradient(colors: [.black.opacity(0.6), .black.opacity(0.25), .black.opacity(0.6)])
            let lightGradient = Gradient(colors: [.white.opacity(0.05), .white.opacity(0.55), .white.opacity(0.05)])

            // (c) scroll the bands with the drag.
            let normalized = ridgePhase.truncatingRemainder(dividingBy: pitch)
            var y = normalized >= 0 ? normalized - pitch : normalized
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: darkBand)),
                             with: .linearGradient(darkGradient, startPoint: start, endPoint: end))
                context.fill(Path(CGRect(x: 0, y: y + darkBand, width: size.width, height: lightBand)),
                             with: .linearGradient(lightGradient, startPoint: start, endPoint: end))
                y += pitch
            }
        }
        .frame(width: width, height: height)
        .clipShape(Capsule())                                              // (d)
        .overlay(Capsule().stroke(.black.opacity(0.7), lineWidth: metrics.pt(1)))   // (e)
    }
}
