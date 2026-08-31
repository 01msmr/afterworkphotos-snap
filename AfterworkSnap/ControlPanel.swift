import SwiftUI
import UIKit

/// A recessed bezel holding a custom-drawn cylindrical "drum" — the
/// numbers "[n]" printed around a rolling drum, seen face-on — for
/// stepping through the six suggested names, and the regenerate button
/// (fetch six new names). `mirrored`: the drum and button swap sides
/// (used when the whole panel sits on the left). The panel itself is a
/// fixed 96 × 72; the drum's own face is deliberately the *opposite*
/// tone of its panel in each colour scheme (light mode: dark panel, a
/// light drum; dark mode: light panel, a dark drum), so it always reads
/// as a lit cylinder recessed into its housing rather than one flat slab.
struct ControlPanel: View {
    let count: Int
    @Binding var selection: Int
    let enabled: Bool
    let metrics: Metrics
    let mirrored: Bool
    let onCenter: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var position: Double = 0
    @State private var lastTranslation: CGFloat = 0
    @State private var dragActive = false
    @State private var lastRounded = 0
    @State private var haptic = UISelectionFeedbackGenerator()
    @State private var lastTickAt = Date.distantPast

    var body: some View {
        let height = metrics.wheel      // pt(72), the panel's full height
        let width = height * 4 / 3

        ZStack {
            RoundedRectangle(cornerRadius: metrics.pt(10))
                .fill(scheme == .dark ? Color(white: 0.82) : Color(white: 0.30))
                .overlay(                                        // inset: a blurred dark stroke inward
                    RoundedRectangle(cornerRadius: metrics.pt(10))
                        .inset(by: metrics.pt(1))
                        .stroke(.black.opacity(0.5), lineWidth: metrics.pt(3))
                        .blur(radius: metrics.pt(2))
                        .clipShape(RoundedRectangle(cornerRadius: metrics.pt(10)))
                )
                .overlay(RoundedRectangle(cornerRadius: metrics.pt(10)).stroke(.black.opacity(0.35), lineWidth: metrics.pt(1)))   // rim — kept visible even on the light (dark-mode) panel
                .shadow(color: .white.opacity(0.15), radius: 0, y: metrics.pt(1))   // 1 pt lighter line under the bottom edge

            HStack(spacing: 0) {
                if mirrored {
                    regenerateButton.padding(.leading, metrics.pt(8))
                    Spacer(minLength: 0)
                    drum.padding(.trailing, metrics.pt(8))
                } else {
                    drum.padding(.leading, metrics.pt(8))
                    Spacer(minLength: 0)
                    regenerateButton.padding(.trailing, metrics.pt(8))
                }
            }
            .frame(height: height)   // explicit, so the shorter drum visibly centres with the panel showing above/below it
        }
        .frame(width: width, height: height)
        .saturation(enabled ? 1 : 0)
        .brightness(enabled ? 0 : (scheme == .dark ? -0.1 : -0.18))
    }

    /// A vertical cylinder, seen face-on, `pt(36) × pt(66)` (R = 33; a
    /// pt(3) margin top and bottom inside the 72 pt panel — narrow and
    /// tall, so the rows actually reach the rims). The "[n]" rows are
    /// printed around its circumference and roll past as you drag. Each
    /// visible row sits at angle `θ = (i − position)·0.55`, `y = R + R·sin
    /// θ` — at `position == 0`, row 0 ("[1]") sits exactly at the
    /// vertical centre (`θ == 0`), the neighbour rows land at `y ≈ R ±
    /// 17` and the next at `y ≈ R ± 31` (close to the rims), and nothing
    /// renders above (there is no row `i < 0`) — scaled vertically by
    /// `cos θ` and faded by `cos²θ`: dense and high-contrast at the
    /// centre, compressed and faint near the rims, like a real cylinder.
    /// Rows draw out almost to the pole (`|θ| < (π/2)·0.98`, not a full
    /// `π/2`, so the compression stays finite). A thin separator line
    /// (same mapping, at the half-angle between rows) marks each row
    /// boundary. Dragging rotates `position` continuously, about
    /// `pt(22)` of drag per row; releasing snaps to the nearest whole
    /// index with a spring. Disabled (and greyed) before a shot — the
    /// rows still show, so the panel never looks like a plain flat
    /// filler.
    private var drum: some View {
        let width = metrics.pt(36)
        let height = metrics.wheel - metrics.pt(6)   // pt(66): a pt(3) margin top and bottom inside the 72 pt panel
        let R = height / 2
        let delta = 1.00      // row angle step: the neighbours land at y = R ± R·sin(1.0) ≈ R ± 28 — this, not the face height, sets the room between the numbers
        let rowCount = max(count, 6)
        let isDark = scheme == .dark

        // The drum is the opposite tone of its panel: light mode has a
        // dark panel and a *light* drum (no black rim — a pale cylinder);
        // dark mode has a light panel and the original *dark* drum
        // (black rims fading up to a lit centre).
        // The dark rims now occupy only the outer 6 % each — most of the
        // face is the lit midtone, matching how narrow a band the rows
        // actually compress into near the poles.
        let gradient: Gradient = isDark
            ? Gradient(stops: [
                .init(color: .black, location: 0.0),
                .init(color: Color(white: 0.20), location: 0.06),
                .init(color: Color(white: 0.42), location: 0.50),
                .init(color: Color(white: 0.20), location: 0.94),
                .init(color: .black, location: 1.0),
              ])
            : Gradient(stops: [
                .init(color: Color(white: 0.55), location: 0.0),
                .init(color: Color(white: 0.80), location: 0.06),
                .init(color: Color(white: 0.96), location: 0.50),
                .init(color: Color(white: 0.80), location: 0.94),
                .init(color: Color(white: 0.55), location: 1.0),
              ])
        let strokeColour: Color = isDark ? .black : .black.opacity(0.35)
        let separatorOpacity = isDark ? 0.6 : 0.25
        let realTextColour: Color = isDark ? .white : Color(white: 0.12)
        let placeholderTextColour = Color(white: 0.55)

        return ZStack {
            RoundedRectangle(cornerRadius: metrics.pt(8))
                .fill(LinearGradient(gradient: gradient, startPoint: .top, endPoint: .bottom))
                .overlay(                                          // soft specular band, 42–50 % of height
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: 0.42),
                        .init(color: .white.opacity(0.14), location: 0.46),
                        .init(color: .clear, location: 0.50),
                        .init(color: .clear, location: 1.0),
                    ], startPoint: .top, endPoint: .bottom)
                )
                .overlay(RoundedRectangle(cornerRadius: metrics.pt(8)).stroke(strokeColour, lineWidth: metrics.pt(1)))

            let poleLimit = (Double.pi / 2) * 0.98
            ForEach(0..<rowCount, id: \.self) { i in
                let theta = (Double(i) - position) * delta
                if abs(theta) < poleLimit {
                    Text("[\(i + 1)]")
                        .font(.system(size: metrics.pt(14), weight: .semibold, design: .monospaced))
                        .foregroundStyle(count > 0 ? realTextColour : placeholderTextColour)
                        .scaleEffect(x: 1, y: cos(theta))
                        .opacity(cos(theta) * cos(theta))
                        .position(x: width / 2, y: R - R * sin(theta))
                }
            }
            ForEach(0...rowCount, id: \.self) { i in
                let theta = (Double(i) - 0.5 - position) * delta
                if abs(theta) < poleLimit {
                    Rectangle().fill(.black.opacity(separatorOpacity * cos(theta)))
                        .frame(width: width, height: metrics.pt(1))
                        .position(x: width / 2, y: R - R * sin(theta))
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: metrics.pt(8)))
        .contentShape(Rectangle())
        .onAppear { position = Double(selection); haptic.prepare() }   // a prepared generator ticks without first-use lag
        .onChange(of: selection) { _, new in if !dragActive { position = Double(new) } }
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { g in
                    guard enabled, count > 0 else { return }
                    if !dragActive {
                        dragActive = true
                        haptic.prepare()
                        lastTranslation = 0
                        lastRounded = Int(position.rounded())
                    }
                    let d = g.translation.height - lastTranslation
                    lastTranslation = g.translation.height
                    // The rows follow the finger, like real cylinder under
                    // your thumb: dragging down brings the previous (lower)
                    // row into the centre; dragging up brings the next
                    // (higher) row — about pt(22) of drag per row.
                    position += d / metrics.pt(22)
                    position = min(max(position, 0), Double(count - 1))
                    let rounded = Int(position.rounded())
                    if rounded != lastRounded {
                        lastRounded = rounded
                        haptic.selectionChanged()
                        // one tick per row (length, not time), pitch
                        // rising with how fast the drum is spun
                        let now = Date()
                        let speed = min(1, max(0, (0.30 - now.timeIntervalSince(lastTickAt)) / 0.27))
                        lastTickAt = now
                        Sounds.play("tick", speed: speed)
                        selection = rounded
                    }
                }
                .onEnded { _ in
                    dragActive = false
                    lastTranslation = 0
                    withAnimation(.spring(duration: 0.25)) { position = position.rounded() }
                }
        )
        .disabled(!enabled || count == 0)
    }

    private var regenerateButton: some View {
        Button(action: { if enabled { onCenter() } }) {
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: metrics.pt(16), weight: .bold))
                .foregroundStyle(enabled ? (scheme == .dark ? Theme.titleBlueDark : Theme.titleBlue) : Color(white: 0.48))
                .frame(width: metrics.pt(30), height: metrics.pt(30))
                .modifier(Dome(radius: metrics.pt(15)))
        }
        .buttonStyle(.plain)
    }
}
