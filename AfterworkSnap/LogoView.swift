import SwiftUI

struct LogoView: View {
    let size: CGFloat
    var body: some View {
        let font = Font.system(size: size, weight: .black, design: .serif).italic()
        ZStack {
            Text("Snap").font(font).foregroundStyle(.black)
                .offset(x: 1, y: 1)
            Text("Snap").font(font).foregroundStyle(.black)
                .offset(x: -1, y: -1)
            Text("Snap").font(font)
                .foregroundStyle(LinearGradient(colors: [Color(white: 0.99), Color(white: 0.72), Color(white: 0.55), Color(white: 0.86)],
                                                startPoint: .top, endPoint: .bottom))
        }
        .shadow(color: .white.opacity(0.35), radius: 0, y: -1)
        .shadow(color: .black.opacity(0.6), radius: 0, y: 1)
    }
}
