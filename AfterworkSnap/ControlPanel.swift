import SwiftUI
import UIKit

/// A recessed dark bezel holding a custom-drawn cylindrical "drum" — the
/// numbers "[n]" printed around a rolling drum, seen face-on — for
/// stepping through the six suggested names, and the regenerate button
/// (fetch six new names). `mirrored`: the drum and button swap sides
/// (used when the whole panel sits on the left). The panel itself is a
/// fixed 96 × 72 — only the drum inside it is custom-drawn; the button
/// is unchanged apart from its new, smaller diameter.
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

    var body: some View {
        let height = metrics.wheel      // pt(72), the panel's full height
        let width = height * 4 / 3

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
        }
        .frame(width: width, height: height)
        .saturation(enabled ? 1 : 0)
        .brightness(enabled ? 0 : (scheme == .dark ? -0.1 : -0.18))
    }

    /// A vertical cylinder, seen face-on, `pt(47) × pt(64)` (R = 32): the
    /// "[n]" rows are printed around its circumference and roll past as
    /// you drag. Each visible row sits at angle `θ = (i - position)·0.42`,
    /// `y = R − R·sin θ`, scaled vertically by `cos θ` and faded by
    /// `cos²θ` — dense and high-contrast at the centre, compressed and
    /// faint near the rims, like a real cylinder; a thin separator line
    /// (same mapping, at the half-angle between rows) marks each row
    /// boundary. Dragging rotates `position` continuously; releasing
    /// snaps to the nearest whole index with a spring. Disabled (and
    /// greyed) before a shot — the rows still show, so the panel never
    /// looks like a plain flat filler.
    private var drum: some View {
        let width = metrics.pt(47)
        let height = metrics.pt(64)
        let R = height / 2
        let delta = 0.42
        let rowCount = max(count, 6)
        let isDark = scheme == .dark
        let mid1 = isDark ? 0.20 : 0.28
        let mid2 = isDark ? 0.42 : 0.55

        return ZStack {
            RoundedRectangle(cornerRadius: metrics.pt(8))
                .fill(LinearGradient(stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: Color(white: mid1), location: 0.20),
                    .init(color: Color(white: mid2), location: 0.50),
                    .init(color: Color(white: mid1), location: 0.80),
                    .init(color: .black, location: 1.0),
                ], startPoint: .top, endPoint: .bottom))
                .overlay(                                          // soft specular band, 42–50 % of height
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: 0.42),
                        .init(color: .white.opacity(0.14), location: 0.46),
                        .init(color: .clear, location: 0.50),
                        .init(color: .clear, location: 1.0),
                    ], startPoint: .top, endPoint: .bottom)
                )
                .overlay(RoundedRectangle(cornerRadius: metrics.pt(8)).stroke(.black, lineWidth: metrics.pt(1)))

            ForEach(0..<rowCount, id: \.self) { i in
                let theta = (Double(i) - position) * delta
                if abs(theta) < .pi / 2 {
                    Text("[\(i + 1)]")
                        .font(.system(size: metrics.pt(13), weight: .semibold, design: .monospaced))
                        .foregroundStyle(count > 0 ? .white : Color(white: 0.55))
                        .scaleEffect(x: 1, y: cos(theta))
                        .opacity(cos(theta) * cos(theta))
                        .position(x: width / 2, y: R - R * sin(theta))
                }
            }
            ForEach(0...rowCount, id: \.self) { i in
                let theta = (Double(i) - 0.5 - position) * delta
                if abs(theta) < .pi / 2 {
                    Rectangle().fill(.black.opacity(0.5 * cos(theta)))
                        .frame(width: width, height: metrics.pt(1))
                        .position(x: width / 2, y: R - R * sin(theta))
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: metrics.pt(8)))
        .contentShape(Rectangle())
        .onAppear { position = Double(selection) }
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
                    // Dragging down rolls the cylinder to the next (higher) row.
                    position += d / (R * delta)
                    position = min(max(position, 0), Double(count - 1))
                    let rounded = Int(position.rounded())
                    if rounded != lastRounded {
                        lastRounded = rounded
                        haptic.selectionChanged()
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
