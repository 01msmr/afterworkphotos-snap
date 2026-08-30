import SwiftUI

/// The spec's constants. Points for a 393-wide screen; `Metrics` scales them.
struct Metrics {
    let scale: CGFloat
    init(width: CGFloat) { scale = width / 393 }
    func pt(_ v: CGFloat) -> CGFloat { v * scale }
    var side: CGFloat { 0.04 }                 // fraction of width
    var titleTop: CGFloat { pt(12) }
    var titleHeight: CGFloat { pt(44) }
    var printTop: CGFloat { pt(56) }
    var gapLogo: CGFloat { pt(24) }
    var logoSize: CGFloat { pt(26) }
    var gapShutter: CGFloat { pt(24) }
    var shutter: CGFloat { pt(96) }
    var wheel: CGFloat { pt(72) }
    var gapLCD: CGFloat { pt(32) }
    var lcdHeight: CGFloat { pt(78) }
    var slideW: CGFloat { pt(104) }
    var slideH: CGFloat { pt(40) }
    var knob: CGFloat { pt(32) }
    var slideBottom: CGFloat { pt(30) }
    var labelInset: CGFloat { pt(16) }
}

enum Theme {
    static let titleBlue = Color(red: 0, green: 0, blue: 1)
    static let titleBlueDark = Color(red: 0x9d/255, green: 0xb8/255, blue: 1)
    static let shutterTop = Color(red: 1, green: 0x5a/255, blue: 0x4e/255)
    static let shutterMid = Color(red: 0xc8/255, green: 0x10/255, blue: 0x0a/255)
    static let shutterEdge = Color(red: 0x8e/255, green: 0x05/255, blue: 0)
    static let breathTop = Color(red: 0x6a/255, green: 0x04/255, blue: 0)
    static let breathEdge = Color(red: 0x3a/255, green: 0x02/255, blue: 0)
    static let lcdTop = Color(red: 0xc9/255, green: 0xd3/255, blue: 0xc2/255)
    static let lcdBottom = Color(red: 0xb9/255, green: 0xc4/255, blue: 0xb2/255)
    static let lcdInk = Color(red: 0x1b/255, green: 0x2a/255, blue: 0x1b/255)
    static let track = Color(red: 0x8c/255, green: 0x8c/255, blue: 0x8c/255)
    static let red = Color(red: 0xc8/255, green: 0x10/255, blue: 0x0a/255)
    static let green = Color(red: 0x1a/255, green: 0x9a/255, blue: 0x3a/255)
    static let siteBlueLight = titleBlue

    static func body(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0x16/255, green: 0x16/255, blue: 0x16/255)
                        : Color(red: 0xde/255, green: 0xde/255, blue: 0xde/255)
    }
    static func title(_ scheme: ColorScheme) -> Color { scheme == .dark ? titleBlueDark : titleBlue }
    /// The print's recess shade (the site's --shade) and edge light.
    static func shade(_ scheme: ColorScheme) -> Color { scheme == .dark ? .black : Color(red: 40/255, green: 30/255, blue: 20/255) }
    static func edgeLight(_ scheme: ColorScheme) -> Color { .white.opacity(scheme == .dark ? 0.14 : 0.55) }
}

/// The leather: the tile from the asset catalog, repeated at 150 pt, under a wide top light.
struct Leather: View {
    @Environment(\.colorScheme) private var scheme
    let metrics: Metrics
    var body: some View {
        ZStack {
            Theme.body(scheme)
            Image(scheme == .dark ? "LeatherDark" : "LeatherLight")
                .resizable(resizingMode: .tile)
                .scaleEffect(metrics.pt(150) / 256, anchor: .topLeading)
                .clipped()
            RadialGradient(colors: [.white.opacity(scheme == .dark ? 0.10 : 0.35), .black.opacity(scheme == .dark ? 0.35 : 0.08)],
                           center: .top, startRadius: 0, endRadius: metrics.pt(900))
        }
        .ignoresSafeArea()
    }
}

/// A domed button face: radial highlight top-left, dark rim, drop shadow.
struct Dome: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .background(
                Circle().fill(RadialGradient(colors: scheme == .dark ? [Color(white: 0.24), Color(white: 0.08)] : [Color(white: 0.95), Color(white: 0.77)],
                                             center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: 60))
            )
            .overlay(Circle().stroke(Color.black.opacity(scheme == .dark ? 1 : 0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
    }
}
