import SwiftUI
import AVFoundation

/// The chrome release: a satin disc, machined into the leather.
///
/// Every measure is physical, converted per device by `Metrics.mm`. One
/// material to the very edge: the face is dead flat, the outer 1 mm
/// simply rounds away — a soft darkening, no rim. Satin, not gloss: the
/// reflection — the front camera's mirrored feed, or a drawn silhouette
/// without multi-cam — sits blurred, a quarter desaturated and 15 %
/// darker in the metal. Around the disc: 0.2 mm of black gap, then the
/// leather rolling into the well at 0.5 mm.
///
/// The mechanics (a real UIKit touch view, not a SwiftUI `Button`, so
/// the finger's contact patch is readable): pressing sinks the disc
/// 1.5 mm with the dome's click; as the fingertip peels off, its contact
/// radius collapses *before* the touch ends — at that moment the button
/// pushes back and the spring's tick plays, while there is still skin on
/// the glass to feel it. The shot itself fires on touch-up, as before.
/// `onTouch` reports finger-down/up so the voice trigger can hold its
/// tongue while the button is being worked. `locked` swallows the press
/// and answers with a dead double-knock.
struct ShutterButton: View {
    let size: CGFloat
    let metrics: Metrics
    let locked: Bool
    let reflection: AVCaptureVideoPreviewLayer?
    let onTouch: (Bool) -> Void
    let action: () -> Void
    @State private var sunk = false

    var body: some View {
        let gap = metrics.mm(0.2)
        let lip = metrics.mm(0.5)
        let wellR = size / 2 + gap + lip
        disc
            .modifier(Sink(metrics: metrics, sunk: sunk))
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
            .overlay(
                ShutterTouch(
                    onDown: {
                        onTouch(true)
                        if locked { ShutterHaptics.shared.locked() }
                        else { sunk = true; ShutterHaptics.shared.press() }
                    },
                    onSpringBack: {
                        // The fingertip is peeling off: push back NOW,
                        // while it can still feel the spring.
                        if sunk { sunk = false; ShutterHaptics.shared.release() }
                    },
                    onUp: { fire in
                        if sunk { sunk = false; ShutterHaptics.shared.release() }   // fast tap: never sprang early
                        onTouch(false)
                        if fire && !locked { action() }
                    }
                )
            )
            .onAppear { ShutterHaptics.shared.prepare() }
    }

    /// The disc: one satin surface. The reflection fills it edge to edge,
    /// softly blurred; the 1 mm roundover is only a darkening at the rim.
    private var disc: some View {
        let edge = metrics.mm(1)
        return ZStack {
            if let reflection {
                PreviewView(layer: reflection)
                    .scaleEffect(1.06)                 // keeps the blur's hazy border under the clip
                    .blur(radius: metrics.mm(1.2))     // satin: shiny, not glossy
                    .saturation(0.75)                  // a quarter of the colour gone
                    .brightness(-0.05)                 // barely dimmed — the shine stays light
            } else {
                LinearGradient(stops: [
                    .init(color: Color(white: 0.90), location: 0),
                    .init(color: Color(white: 0.78), location: 0.5),
                    .init(color: Color(white: 0.70), location: 1),
                ], startPoint: .top, endPoint: .bottom)
                photographer
            }
            LinearGradient(stops: [   // a breath of metal over the image
                .init(color: .white.opacity(0.18), location: 0),
                .init(color: Color(white: 0.5).opacity(0.06), location: 0.5),
                .init(color: .black.opacity(0.22), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            Circle().fill(RadialGradient(stops: [   // the roundover: same material turning from the light
                .init(color: .clear, location: 0),
                .init(color: .clear, location: (size / 2 - edge) / (size / 2)),
                .init(color: .black.opacity(0.40), location: 1),
            ], center: .center, startRadius: 0, endRadius: size / 2))
        }
        .clipShape(Circle())
        .brightness(locked ? -0.15 : 0)
        .animation(.linear(duration: 0.2), value: locked)
    }

    /// The fallback reflection: head, shoulders, the raised phone — soft and dark.
    private var photographer: some View {
        let inner = size
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
        .blur(radius: 2.5)
        .opacity(0.5)
    }
}

/// The sink: 1.5 mm in — a small settle downward, a dimmer face, the
/// well's shadow on the upper edge and a collapsed drop shadow — and the
/// spring back out. The disc itself never changes shape.
private struct Sink: ViewModifier {
    let metrics: Metrics
    let sunk: Bool
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle().stroke(.black.opacity(0.45), lineWidth: metrics.mm(0.9))
                    .blur(radius: metrics.mm(0.45))
                    .clipShape(Circle())
                    .opacity(sunk ? 1 : 0)
            )
            .brightness(sunk ? -0.10 : 0)
            .offset(y: sunk ? metrics.mm(0.3) : 0)
            .shadow(color: .black.opacity(0.55),
                    radius: sunk ? metrics.mm(0.25) : metrics.mm(0.8),
                    y: sunk ? metrics.mm(0.1) : metrics.mm(0.35))
            .animation(.easeOut(duration: 0.07), value: sunk)
    }
}

/// Raw touches for the release, because SwiftUI can't see the finger's
/// contact patch. `UITouch.majorRadius` grows as the fingertip settles
/// and collapses as it peels off — when it falls below 60 % of the
/// largest radius this touch has shown, the finger is leaving even
/// though the touch hasn't ended yet: that's `onSpringBack`. `onUp(true)`
/// on a real touch-up (the shot), `onUp(false)` on cancellation.
private struct ShutterTouch: UIViewRepresentable {
    let onDown: () -> Void
    let onSpringBack: () -> Void
    let onUp: (Bool) -> Void

    final class TouchView: UIView {
        var onDown: (() -> Void)?
        var onSpringBack: (() -> Void)?
        var onUp: ((Bool) -> Void)?
        private var tracking = false
        private var sprung = false
        private var maxRadius: CGFloat = 0

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard !tracking, let t = touches.first else { return }
            tracking = true; sprung = false
            maxRadius = t.majorRadius
            onDown?()
        }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard tracking, !sprung, let t = touches.first else { return }
            let r = t.majorRadius
            maxRadius = max(maxRadius, r)
            if maxRadius > 0, r < maxRadius * 0.6 {
                sprung = true
                onSpringBack?()
            }
        }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard tracking else { return }
            tracking = false
            onUp?(true)
        }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard tracking else { return }
            tracking = false
            onUp?(false)
        }
    }

    func makeUIView(context: Context) -> TouchView {
        let v = TouchView()
        v.isMultipleTouchEnabled = false
        v.backgroundColor = .clear
        v.onDown = onDown; v.onSpringBack = onSpringBack; v.onUp = onUp
        return v
    }
    func updateUIView(_ v: TouchView, context: Context) {
        v.onDown = onDown; v.onSpringBack = onSpringBack; v.onUp = onUp
    }
}
