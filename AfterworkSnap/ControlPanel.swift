import SwiftUI

/// A recessed dark bezel holding the system's own wheel picker — the
/// "drum" — for stepping through the six suggested names, and the
/// regenerate button (fetch six new names). `mirrored`: the drum and
/// button swap sides (used when the whole panel sits on the left).
struct ControlPanel: View {
    let count: Int
    @Binding var selection: Int
    let enabled: Bool
    let metrics: Metrics
    let mirrored: Bool
    let onCenter: () -> Void
    @Environment(\.colorScheme) private var scheme

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

    /// The system's own wheel picker, styled as the LCD's "drum": one row
    /// per suggested name, "[n]"; with no names yet, six placeholder rows
    /// "[1]"…"[6]" (dimmer text, disabled) — never a lone "-". Row text is
    /// forced white in both colour schemes (the panel is always dark), and
    /// the whole picker is forced to `.dark` in case `.pickerStyle(.wheel)`
    /// ignores `.foregroundStyle` on its own chrome.
    private var drum: some View {
        Picker("", selection: $selection) {
            if count > 0 {
                ForEach(0..<count, id: \.self) { i in
                    Text("[\(i + 1)]").font(.system(size: metrics.pt(15), weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white).tag(i)
                }
            } else {
                ForEach(0..<6, id: \.self) { i in
                    Text("[\(i + 1)]").font(.system(size: metrics.pt(15), weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.55)).tag(i)
                }
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .environment(\.colorScheme, .dark)
        .frame(width: metrics.pt(48), height: metrics.pt(72))
        .clipShape(RoundedRectangle(cornerRadius: metrics.pt(8)))
        .disabled(!enabled || count == 0)
    }

    private var regenerateButton: some View {
        Button(action: { if enabled { onCenter() } }) {
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: metrics.pt(16), weight: .bold))
                .foregroundStyle(enabled ? (scheme == .dark ? Theme.titleBlueDark : Theme.titleBlue) : Color(white: 0.48))
                .frame(width: metrics.pt(36), height: metrics.pt(36))
                .modifier(Dome(radius: metrics.pt(18)))
        }
        .buttonStyle(.plain)
    }
}
