import SwiftUI

/// A knob you drag along a track. Fires past 85 %; snaps back below.
/// `mirrored`: knob at rest at the right, travels left (retake).
///
/// Built without `scaleEffect`: the rest edge (where the knob sits at
/// offset 0) and the far edge (where it travels to, and fires) are simply
/// swapped between `.leading` and `.trailing` depending on `mirrored`, so
/// the label text is never drawn backwards.
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
    let onFire: () -> Void
    @State private var offset: CGFloat = 0

    private var travel: CGFloat { metrics.slideW - metrics.knob - metrics.pt(8) }
    private var progress: CGFloat { offset / travel }

    var body: some View {
        let w = metrics.slideW, h = metrics.slideH, k = metrics.knob
        let restEdge: Edge.Set = mirrored ? .trailing : .leading
        let farEdge: Edge.Set = mirrored ? .leading : .trailing
        let restAlign: Alignment = mirrored ? .trailing : .leading
        let farAlign: Alignment = mirrored ? .leading : .trailing
        // The colour fill's own geometry — label B's mask uses exactly this,
        // so it can only ever show through where the fill already is.
        let fillWidth: CGFloat = (enabled && offset > 0) ? metrics.pt(4) + offset + k / 2 : 0
        // The knob's own leading (outer-facing) edge, as a distance from
        // the rest edge — label A's mask is the strip from there to the
        // outer end, so the knob's advance is what wipes it away.
        let knobLeadingEdge = metrics.pt(4) + offset + k
        let labelAMaskWidth = max(0, w - knobLeadingEdge)

        ZStack(alignment: restAlign) {
            Capsule().fill(Theme.track)
                .overlay(Capsule().strokeBorder(.black.opacity(0.45), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 2, y: 2)   // recessed
            if fillWidth > 0 {
                Rectangle().fill(colour).frame(width: fillWidth).clipShape(Capsule())
            }
            // Label A: fixed at the outer end, masked by the untravelled strip
            // between the knob's leading edge and the outer end.
            Text(label).font(.system(size: metrics.pt(12), weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: farAlign)
                .padding(farEdge, metrics.labelInset)
                .mask(alignment: farAlign) { Rectangle().frame(width: labelAMaskWidth) }
                .transaction { $0.animation = nil }
            // Label B: fixed 16 pt from the inner end, masked by the fill's
            // own geometry — revealed exactly as the fill grows over it.
            Text(label).font(.system(size: metrics.pt(12), weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: restAlign)
                .padding(restEdge, metrics.labelInset)
                .mask(alignment: restAlign) { Rectangle().frame(width: fillWidth) }
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
                    if enabled && progress >= 0.85 { onFire() }
                    withAnimation(.spring(duration: 0.25)) { offset = 0 }
                })
        }
        .frame(width: w, height: h)
    }
}
