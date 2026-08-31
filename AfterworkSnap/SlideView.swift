import SwiftUI
import UIKit

/// A knob you drag along a track. Fires past 85 %; snaps back below.
/// `mirrored`: knob at rest at the right, travels left (retake).
///
/// Built without `scaleEffect`: the rest edge (where the knob sits at
/// offset 0) and the far edge (where it travels to, and fires) are simply
/// swapped between `.leading` and `.trailing` depending on `mirrored`, so
/// the label text is never drawn backwards.
///
/// The track's own width follows its label — `sizingLabels` lists every
/// word this slide might ever show (for the post slide, both POST/POSTEN
/// and RETRY/ERNEUT, so its width never jumps when the label changes);
/// the width is the widest of those, measured with the same weight/size
/// the label itself renders at, plus the knob, its gap, and the label's
/// outer margin on both sides — never narrower than a pt(96) minimum.
///
/// Two labels, both always drawn — nothing is ever hidden by opacity
/// anywhere, only by masks tied to real geometry:
///  - Label A sits fixed at the outer end. It's masked by the rectangle
///    from the knob's leading edge (the edge facing the outer end) to the
///    outer end of the track — so as the knob slides outward it wipes
///    label A away letter by letter, and reveals it again on the way back.
///  - Label B is the same word, fixed 16 pt from the inner end (the same
///    position the old "sliding" label held), masked by a rectangle with
///    exactly the colour fill's own geometry — at rest the fill (and so
///    the mask) is zero-width, so nothing of it shows; it's revealed as
///    the fill grows, in lockstep, never independently of it.
/// Both labels carry `.transaction { $0.animation = nil }` so neither the
/// knob's spring snap-back nor a label text change (POST ↔ RETRY) can
/// animate them. The knob is drawn last, so it stays above both labels.
struct SlideView: View {
    let label: String
    let colour: Color
    let mirrored: Bool
    let enabled: Bool
    let metrics: Metrics
    let sizingLabels: [String]
    let onFire: () -> Void
    @State private var offset: CGFloat = 0

    /// The knob, its gap, the widest label this slide can show, and the
    /// label's own margin on both sides — never below the pt(96) minimum —
    /// then a third of a knob taken back off: the slides run deliberately
    /// tight, a shorter throw.
    private var width: CGFloat {
        let font = UIFont.systemFont(ofSize: metrics.pt(12), weight: .semibold)
        let widest = sizingLabels
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        let natural = metrics.knob + metrics.pt(8) + widest + 2 * metrics.labelInset
        return max(metrics.pt(96), natural) - metrics.knob / 3
    }
    private var travel: CGFloat { width - metrics.knob - metrics.pt(8) }
    private var progress: CGFloat { offset / travel }

    var body: some View {
        let w = width, h = metrics.slideH, k = metrics.knob
        let restEdge: Edge.Set = mirrored ? .trailing : .leading
        let farEdge: Edge.Set = mirrored ? .leading : .trailing
        let restAlign: Alignment = mirrored ? .trailing : .leading
        let farAlign: Alignment = mirrored ? .leading : .trailing
        // The colour fill's own geometry — from the rest end to 4 pt beyond
        // the knob's far edge, so the fill encircles the knob (a 4 pt ring
        // of colour around it) rather than stopping behind it. Always
        // present (even at rest, offset == 0) so the active knob already
        // sits in its ring before any sliding; inactive slides show the
        // same ring, just in a darker grey, hinting where the colour will
        // appear once enabled. The ring is solid — Label B must never
        // show through it, so Label B's own mask (below) stops 4 pt
        // before the knob's near edge, not at the fill's own far edge.
        let fillWidth: CGFloat = metrics.pt(4) + offset + k + metrics.pt(4)
        let fillColour: Color = enabled ? colour : Color(white: 0.58)
        // The fill's start, up to 4 pt before the knob's near edge — i.e.
        // excluding the knob and its solid ring. At rest (offset == 0)
        // this is 0, so Label B is fully hidden until the knob has
        // actually moved away from it.
        let labelBMaskWidth = max(0, (metrics.pt(4) + offset) - metrics.pt(4))
        // The ring's own OUTER edge (4 pt beyond the knob's leading edge —
        // i.e. exactly `fillWidth`), as a distance from the rest end —
        // label A's mask is the strip from there to the outer end, so the
        // ring's advance (not just the knob's) is what wipes it away; the
        // ring itself is always solid colour, never see-through.
        let labelAMaskWidth = max(0, w - fillWidth)

        ZStack(alignment: restAlign) {
            Capsule().fill(Theme.track)
                .overlay(Capsule().strokeBorder(.black.opacity(0.45), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 2, y: 2)   // recessed
            Rectangle().fill(fillColour).frame(width: fillWidth).clipShape(Capsule())
            // Label A: fixed at the outer end, masked by the untravelled strip
            // between the knob's leading edge and the outer end.
            Text(label).font(.system(size: metrics.pt(12), weight: .semibold)).foregroundStyle(enabled ? .white : Color(white: 0.72))
                .frame(maxWidth: .infinity, alignment: farAlign)
                .padding(farEdge, metrics.labelInset)
                .mask(alignment: farAlign) { Rectangle().frame(width: labelAMaskWidth) }
                .transaction { $0.animation = nil }
            // Label B: fixed 16 pt from the inner end, masked by the fill
            // MINUS the knob-and-ring — revealed only behind where the
            // knob has already passed, never showing through the ring.
            Text(label).font(.system(size: metrics.pt(12), weight: .semibold)).foregroundStyle(enabled ? .white : Color(white: 0.72))
                .frame(maxWidth: .infinity, alignment: restAlign)
                .padding(restEdge, metrics.labelInset)
                .mask(alignment: restAlign) { Rectangle().frame(width: labelBMaskWidth) }
                .transaction { $0.animation = nil }
            Color.clear.frame(width: k, height: k)
                .modifier(Dome(radius: k / 2))
                .saturation(enabled ? 1 : 0).brightness(enabled ? 0 : -0.15)
                .padding(restEdge, metrics.pt(4))
                .offset(x: mirrored ? -offset : offset)
                .gesture(DragGesture().onChanged { g in
                    guard enabled else { return }
                    let dx = mirrored ? -g.translation.width : g.translation.width
                    offset = min(max(0, dx), travel)
                }.onEnded { _ in
                    if enabled && progress >= 0.85 { Sounds.play("tick"); onFire() }
                    withAnimation(.spring(duration: 0.25)) { offset = 0 }
                })
        }
        .frame(width: w, height: h)
    }
}
