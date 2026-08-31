import SwiftUI
import AVFoundation

/// The chrome release: a polished disc, machined into the leather.
///
/// Every measure is physical, converted per device by `Metrics.mm`. The
/// face is dead flat and only the outer 1 mm rounds off, drawn as an
/// angular ring of chrome turning away from the light. In the face sits
/// the real reflection: the front camera's mirrored feed (`reflection`),
/// under a breath of chrome — or, where multi-cam isn't supported, a
/// drawn silhouette of the photographer. Around the disc: a 0.2 mm black
/// gap, then the leather, which rolls *into* the well at 0.5 mm — a
/// roundover like the button's own, darkening as it turns down; no
/// bright ring. Pressing sinks the disc 1.5 mm — on screen a small
/// settle, a dimmed face and the well's shadow across the upper edge —
/// and the shot fires on release (a SwiftUI `Button`'s touch-up). The
/// disc keeps its form: no glass, no breathing, no colour change;
/// `locked` only dims it and swallows the press.
struct ShutterButton: View {
    let size: CGFloat
    let metrics: Metrics
    let locked: Bool
    let reflection: AVCaptureVideoPreviewLayer?
    let action: () -> Void

    var body: some View {
        let gap = metrics.mm(0.2)
        let lip = metrics.mm(0.5)
        let wellR = size / 2 + gap + lip
        Button(action: { if !locked { action() } }) {
            disc
        }
        .buttonStyle(PressStyle(metrics: metrics, locked: locked))
        .frame(width: size, height: size)
        .background(
            ZStack {
                Circle()   // the leather rolls in: dark at the hole, back level outside
                    .fill(RadialGradient(stops: [
                        .init(color: .black.opacity(0.55), location: 0),
                        .init(color: .black.opacity(0.55), location: (size / 2 + gap) / wellR),
                        .init(color: .black.opacity(0), location: 1),
                    ], center: .center, startRadius: 0, endRadius: wellR))
                    .frame(width: wellR * 2, height: wellR * 2)
                Circle().fill(.black)   // the 0.2 mm gap
                    .frame(width: size + 2 * gap, height: size + 2 * gap)
            }
        )
    }

    /// The disc: the 1 mm roundover as an angular ring of darker chrome;
    /// inside it the flat face with the reflection in it.
    private var disc: some View {
        let edge = metrics.mm(1)
        return ZStack {
            Circle().fill(AngularGradient(stops: [
                .init(color: Color(white: 0.86), location: 0),
                .init(color: Color(white: 0.51), location: 0.14),
                .init(color: Color(white: 0.28), location: 0.30),
                .init(color: Color(white: 0.68), location: 0.46),
                .init(color: Color(white: 0.94), location: 0.55),
                .init(color: Color(white: 0.55), location: 0.68),
                .init(color: Color(white: 0.31), location: 0.82),
                .init(color: Color(white: 0.78), location: 0.93),
                .init(color: Color(white: 0.86), location: 1),
            ], center: .center, angle: .degrees(200)))
            ZStack {
                if let reflection {
                    PreviewView(layer: reflection)
                    LinearGradient(stops: [   // into the metal: a breath of chrome over the image
                        .init(color: .white.opacity(0.22), location: 0),
                        .init(color: Color(white: 0.5).opacity(0.08), location: 0.5),
                        .init(color: .black.opacity(0.28), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                } else {
                    Circle().fill(LinearGradient(stops: [
                        .init(color: Color(white: 0.90), location: 0),
                        .init(color: Color(white: 0.78), location: 0.5),
                        .init(color: Color(white: 0.70), location: 1),
                    ], startPoint: .top, endPoint: .bottom))
                    photographer
                }
            }
            .clipShape(Circle())
            .padding(edge)
        }
        .brightness(locked ? -0.15 : 0)
        .animation(.linear(duration: 0.2), value: locked)
    }

    /// The fallback reflection: head, shoulders, the raised phone — soft and dark.
    private var photographer: some View {
        let inner = size - 2 * metrics.mm(1)
        let ink = Color(red: 0x18/255, green: 0x1d/255, blue: 0x22/255)
        return ZStack {
            Circle().fill(ink)
                .frame(width: inner * 0.26, height: inner * 0.26)
                .offset(y: -inner * 0.20)
            UnevenRoundedRectangle(topLeadingRadius: inner * 0.16, topTrailingRadius: inner * 0.16)
                .fill(ink)
                .frame(width: inner * 0.56, height: inner * 0.42)
                .offset(y: inner * 0.24)
            RoundedRectangle(cornerRadius: inner * 0.035)
                .fill(Color(red: 0x0b/255, green: 0x0e/255, blue: 0x11/255))
                .frame(width: inner * 0.17, height: inner * 0.27)
                .offset(y: inner * 0.02)
        }
        .blur(radius: 1.5)
        .opacity(0.5)
    }
}

/// The press: sink on touch, fire on release. The sink reads as a small
/// settle downward, a dimmer face, the well's shadow on the upper edge
/// and a collapsed drop shadow — the disc itself never changes shape.
private struct PressStyle: ButtonStyle {
    let metrics: Metrics
    let locked: Bool
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !locked
        return configuration.label
            .overlay(
                Circle().stroke(.black.opacity(0.45), lineWidth: metrics.mm(0.9))
                    .blur(radius: metrics.mm(0.45))
                    .clipShape(Circle())
                    .opacity(pressed ? 1 : 0)
            )
            .brightness(pressed ? -0.10 : 0)
            .offset(y: pressed ? metrics.mm(0.3) : 0)
            .shadow(color: .black.opacity(0.55),
                    radius: pressed ? metrics.mm(0.25) : metrics.mm(0.8),
                    y: pressed ? metrics.mm(0.1) : metrics.mm(0.35))
            .animation(.easeOut(duration: 0.07), value: pressed)
    }
}
