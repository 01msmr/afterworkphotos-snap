import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()
    private let side: CGFloat = 24     // equal side margins around the square

    var body: some View {
        GeometryReader { geo in
            let square = geo.size.width - 2 * side
            VStack(alignment: .trailing, spacing: 8) {
                ZStack {
                    PreviewView(session: model.camera.session)
                    if let data = model.square, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                    }
                }
                .frame(width: square, height: square)
                .clipped()

                Text("afterworksnap")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)

                Spacer()

                controls
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, side)
            .padding(.top, geo.safeAreaInsets.top + 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .ignoresSafeArea()
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
                    Button("discard") { model.discard() }.tint(.white)
                    Spacer()
                    Button(retryOrSave) { model.confirm() }.tint(.green)
                }
                .font(.system(size: 17, weight: .medium))
            }
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
