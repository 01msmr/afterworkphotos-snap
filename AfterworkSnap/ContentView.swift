import SwiftUI

/// The site's phone layout, in points: a band of fixed height below the
/// status inset holds the title at the right; the square starts at the
/// band's foot; side margins are 4 % of the width.
struct ContentView: View {
    @State private var model = AppModel()
    private let topGap: CGFloat = 12
    private let titleBand: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width * 0.04
            let square = geo.size.width - 2 * side
            VStack(alignment: .trailing, spacing: 0) {
                // the site's title link colour (CSS blue) for "snap"
                (Text("snap").foregroundStyle(Color(red: 0, green: 0, blue: 1))
                 + Text(".afterworkphotos").foregroundStyle(.white))
                    .font(.system(size: 17, weight: .medium))
                    .frame(height: titleBand)

                ZStack {
                    PreviewView(session: model.camera.session)
                    if let data = model.square, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                    }
                }
                .frame(width: square, height: square)
                .clipped()

                controls
                    .padding(.top, 24)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, side)
            .padding(.top, topGap)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    @ViewBuilder private var controls: some View {
        switch model.phase {
        case .live:
            Color.clear.contentShape(Rectangle()).onTapGesture { model.shoot() }
        case .review, .failed:
            VStack(spacing: 16) {
                if case .failed(let message) = model.phase {
                    Text(message).font(.footnote).foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if !model.hasPlace {
                    Text("no place").font(.footnote).foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Button("discard") { model.discard() }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    Spacer()
                    Button(retryOrSave) { model.confirm() }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                }
                .controlSize(.large)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        case .saving, .sending:
            ProgressView().tint(.white).frame(maxWidth: .infinity)
        case .sent:
            Text("sent").font(.footnote).foregroundStyle(.white.opacity(0.8))
        }
    }

    private var retryOrSave: String {
        if case .failed = model.phase { return "retry" }
        return "save"
    }
}
