import SwiftUI
import UIKit

/// The spec's constants, in points. `scale` shrinks them below the 393 pt
/// reference width (small phones only) but is always 1 at or above it —
/// iPad gets the same point sizes as a standard iPhone. The print itself
/// is sized separately: on iPhone it simply fills the width (4 % side
/// margins); on iPad it shrinks a little so the fixed-height stack of
/// controls below it still fits the screen, and is centred in the extra
/// horizontal room that leaves.
struct Metrics {
    let scale: CGFloat
    let side: CGFloat
    let printSide: CGFloat

    init(width: CGFloat, height: CGFloat) {
        scale = width < 393 ? width / 393 : 1
        if UIDevice.current.userInterfaceIdiom == .pad {
            // gapLogo + logo + gapShutter + shutter + gapLCD + lcd + slideBottom + slideH + spare
            let fixedStack: CGFloat = 24 + 26 + 24 + 96 + 32 + 78 + 30 + 40 + 30
            let fitPrint = height - 56 - fixedStack
            let printSide = min(width * 0.92, fitPrint)
            self.printSide = printSide
            side = max(width * 0.04, (width - printSide) / 2)
        } else {
            let side = width * 0.04
            self.side = side
            printSide = width - 2 * side
        }
    }
    func pt(_ v: CGFloat) -> CGFloat { v * scale }
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
    var slideW: CGFloat { pt(124) }
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

    static func body(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0x16/255, green: 0x16/255, blue: 0x16/255)
                        : Color(red: 0xde/255, green: 0xde/255, blue: 0xde/255)
    }
    static func title(_ scheme: ColorScheme) -> Color { scheme == .dark ? titleBlueDark : titleBlue }
    /// The print's recess shade (the site's --shade) and edge light.
    static func shade(_ scheme: ColorScheme) -> Color { scheme == .dark ? .black : Color(red: 40/255, green: 30/255, blue: 20/255) }
    static func edgeLight(_ scheme: ColorScheme) -> Color { .white.opacity(scheme == .dark ? 0.14 : 0.55) }
}

/// The leather: the tile from the asset catalog, tiled at 150 pt, under a wide top light.
struct Leather: View {
    @Environment(\.colorScheme) private var scheme
    let metrics: Metrics
    var body: some View {
        ZStack {
            Theme.body(scheme)
            Rectangle().fill(ImagePaint(image: Image(scheme == .dark ? "LeatherDark" : "LeatherLight"),
                                        scale: metrics.pt(150) / 256))
            RadialGradient(colors: [.white.opacity(scheme == .dark ? 0.10 : 0.35), .black.opacity(scheme == .dark ? 0.35 : 0.08)],
                           center: .top, startRadius: 0, endRadius: metrics.pt(900))
        }
        .ignoresSafeArea()
    }
}

/// A domed button face: radial highlight top-left, dark rim, drop shadow.
/// `radius`: half the dome's own size, so the highlight scales with it.
struct Dome: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(
                Circle().fill(RadialGradient(colors: scheme == .dark ? [Color(white: 0.24), Color(white: 0.08)] : [Color(white: 0.95), Color(white: 0.77)],
                                             center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: radius * 1.25))
            )
            .overlay(Circle().stroke(Color.black.opacity(scheme == .dark ? 1 : 0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
    }
}
