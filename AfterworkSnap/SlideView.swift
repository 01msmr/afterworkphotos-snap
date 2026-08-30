import SwiftUI

/// A knob you drag along a track. Fires past 85 %; snaps back below.
/// `mirrored`: knob at rest at the right, travels left (retake).
///
/// Built without `scaleEffect`: the rest edge (where the knob sits at
/// offset 0) and the far edge (where it travels to, and fires) are simply
/// swapped between `.leading` and `.trailing` depending on `mirrored`, so
/// the label text is never drawn backwards. At rest the word's edge nearer
/// the far (outer) end sits 16 pt in from it; while sliding, the word's
/// edge nearer the rest (inner) end sits 16 pt in from it, on the colour.
/// Only the knob (and the colour fill trailing it) moves; the labels only
/// switch opacity at the offset == 0 threshold. Passive (disabled) slides
/// show no colour at all, even behind the knob.
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
            // resting label: near edge 16 from the far (outer) end
            Text(label).font(.system(size: metrics.pt(12), weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: farAlign)
                .padding(farEdge, metrics.labelInset)
                .opacity(offset == 0 ? 1 : 0)
            // the same word, fixed on the colour, near edge 16 from the inner end
            Text(label).font(.system(size: metrics.pt(12), weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: restAlign)
                .padding(restEdge, metrics.labelInset)
                .opacity(offset == 0 ? 0 : 1)
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
