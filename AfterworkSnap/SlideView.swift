import SwiftUI

/// A knob you drag along a track. Fires past 85 %; snaps back below.
/// `mirrored`: knob at rest at the right, travels left (retake).
///
/// Built without `scaleEffect`: the rest edge (where the knob sits at
/// offset 0) and the far edge (where it travels to, and fires) are simply
/// swapped between `.leading` and `.trailing` depending on `mirrored`, so
/// the label text is never drawn backwards.
///
/// Two labels, both always drawn — nothing is ever hidden by opacity, so
/// nothing can be seen to move or fade on the first drag:
///  - Label A sits fixed at the outer end, always visible; the knob may
///    slide over it near the end of travel (it's drawn on top).
///  - Label B is the same word, fixed centred on the knob's *resting*
///    position, drawn *under* the knob — at rest the opaque knob covers
///    it entirely, and it's revealed as the knob slides away.
/// Both labels carry `.transaction { $0.animation = nil }` so neither the
/// knob's spring snap-back nor a label text change (POST ↔ RETRY) can
/// animate them.
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

        ZStack(alignment: restAlign) {
            Capsule().fill(Theme.track)
                .overlay(Capsule().strokeBorder(.black.opacity(0.45), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 2, y: 2)   // recessed
            if enabled && offset > 0 {
                Rectangle().fill(colour).frame(width: metrics.pt(4) + offset + k / 2).clipShape(Capsule())
            }
            // Label A: fixed at the outer end, always visible.
            Text(label).font(.system(size: metrics.pt(12), weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: farAlign)
                .padding(farEdge, metrics.labelInset)
                .transaction { $0.animation = nil }
            // Label B: the same word, fixed centred on the knob's resting
            // position — under the knob, so it's covered at rest. Rendered
            // at its natural width (`.fixedSize`) rather than clipped to
            // the knob's own width, so it may peek out beside the knob —
            // accepted, not a bug.
            Text(label).font(.system(size: metrics.pt(12), weight: .semibold)).foregroundStyle(.white)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: k, alignment: .center)
                .padding(restEdge, metrics.pt(4))
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
