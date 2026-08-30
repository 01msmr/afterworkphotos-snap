import SwiftUI
import SnapCore

struct LCDRow: Identifiable { let id: Strings.Key; let value: String }

/// Three rows; one may be inverted; a sign may stand at the right end of the last row.
struct LCDView: View {
    let rows: [LCDRow]
    let invertedRow: Strings.Key?
    let sign: String?
    let signTwitching: Bool
    let language: Language
    let metrics: Metrics
    let enabled: Bool
    let onNameSwipe: (Int) -> Void
    @State private var twitch = false
    @State private var twitchTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                let inverted = row.id == invertedRow
                HStack(alignment: .firstTextBaseline, spacing: metrics.pt(10)) {
                    Text(Strings.t(row.id, language)).font(.system(size: metrics.pt(10), design: .monospaced)).opacity(0.6)
                        .frame(width: metrics.pt(34), alignment: .leading)
                    Text(row.value).font(.system(size: metrics.pt(14), weight: .medium, design: .monospaced)).lineLimit(1)
                    Spacer(minLength: 0)
                    if row.id == .date, let sign {
                        Text(sign).font(.system(size: metrics.pt(12), weight: .bold, design: .monospaced))
                            .padding(.horizontal, metrics.pt(6)).padding(.vertical, metrics.pt(2))
                            .background(Theme.lcdInk).foregroundStyle(Theme.lcdTop)
                            .offset(x: signTwitching && twitch ? metrics.pt(8) : 0)
                    }
                }
                .padding(.horizontal, metrics.pt(12)).frame(maxWidth: .infinity, minHeight: metrics.lcdHeight / 3)
                .background(inverted ? Theme.lcdInk : .clear)
                .foregroundStyle(inverted ? Theme.lcdTop : Theme.lcdInk)
                .contentShape(Rectangle())
                .gesture(row.id == .name && enabled ? DragGesture(minimumDistance: 20).onEnded { g in
                    onNameSwipe(g.translation.width > 0 ? 1 : -1)
                } : nil)
            }
        }
        .frame(height: metrics.lcdHeight)
        .background(LinearGradient(colors: [Theme.lcdTop, Theme.lcdBottom], startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: metrics.pt(5)))
        .overlay(RoundedRectangle(cornerRadius: metrics.pt(5)).stroke(.black.opacity(0.35), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: metrics.pt(7)).stroke(Color(white: 0.05), lineWidth: metrics.pt(4)).padding(-metrics.pt(2)))
        .shadow(color: .white.opacity(0.18), radius: 0, y: 1)
        .onChange(of: signTwitching, initial: true) { _, on in
            twitchTask?.cancel()
            twitch = false
            guard on else { return }
            twitchTask = Task {
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    twitch = true
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    twitch = false
                }
            }
        }
        .onDisappear { twitchTask?.cancel() }
    }
}
