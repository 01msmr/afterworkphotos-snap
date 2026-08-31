import SwiftUI

/// The chrome release: a polished disc, machined into the leather.
///
/// Every measure is physical, converted per device by `Metrics.mm`: the
/// face's edge rounds off at 1 mm, a 0.2 mm black gap rings the button,
/// and the leather lip around the well is itself rounded at 0.5 mm and
/// shaded in relief, like the button's edge. Pressing sinks the disc
/// 1.5 mm — on screen a small settle, a dimmed face and the lip's shadow
/// falling across the upper edge — and the shot fires on release (a
/// SwiftUI `Button`'s touch-up). The face keeps its form: no glass, no
/// breathing, no colour change; `locked` only dims it and swallows the
/// press. In the centre, the photographer's reflection: a dark
/// silhouette, phone raised.
struct ShutterButton: View {
    let size: CGFloat
    let metrics: Metrics
    let locked: Bool
    let action: () -> Void

    var body: some View {
        let gap = metrics.mm(0.2)
        let lip = metrics.mm(0.5)
        Button(action: { if !locked { action() } }) {
            disc
        }
        .buttonStyle(PressStyle(metrics: metrics, locked: locked))
        .frame(width: size, height: size)
        .background(
            ZStack {
                Circle()      // the leather lip: 0.5 mm roundover, lit from above, rolling into the well
                    .fill(LinearGradient(stops: [
                        .init(color: .white.opacity(0.28), location: 0),
                        .init(color: Color(red: 120/255, green: 110/255, blue: 90/255).opacity(0.10), location: 0.4),
                        .init(color: .black.opacity(0.65), location: 1),
                    ], startPoint: .top, endPoint: .bottom))
                    .frame(width: size + 2 * (gap + lip), height: size + 2 * (gap + lip))
                Circle().fill(.black)   // the 0.2 mm gap
                    .frame(width: size + 2 * gap, height: size + 2 * gap)
            }
        )
    }

    /// The disc: the 1 mm roundover as an angular ring of darker chrome
    /// turning away from the light, the flat face a mirrored horizon
    /// with the photographer in it and one glare, top left.
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
                Circle().fill(LinearGradient(stops: [
                    .init(color: Color(white: 0.95), location: 0),
                    .init(color: Color(white: 0.81), location: 0.20),
                    .init(color: Color(white: 0.56), location: 0.42),
                    .init(color: Color(white: 0.28), location: 0.51),
                    .init(color: Color(white: 0.48), location: 0.58),
                    .init(color: Color(white: 0.72), location: 0.78),
                    .init(color: Color(white: 0.89), location: 1),
                ], startPoint: .top, endPoint: .bottom))
                photographer
                Circle().fill(RadialGradient(colors: [.white.opacity(0.75), .clear],
                                             center: UnitPoint(x: 0.36, y: 0.26),
                                             startRadius: 0, endRadius: (size - 2 * edge) * 0.42))
            }
            .clipShape(Circle())
            .padding(edge)
        }
        .brightness(locked ? -0.15 : 0)
        .animation(.linear(duration: 0.2), value: locked)
    }

    /// The reflection: head, shoulders, the raised phone — soft and dark.
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
/// settle downward, a dimmer face, the lip's shadow on the upper edge
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
