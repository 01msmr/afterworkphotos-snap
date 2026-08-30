import SwiftUI
import SnapCore

struct ContentView: View {
    @State private var model = AppModel()
    @Environment(\.colorScheme) private var scheme
    @AppStorage("panelOnLeft") private var panelOnLeft = false

    var body: some View {
        GeometryReader { geo in
            let m = Metrics(width: geo.size.width, height: geo.size.height)
            let side = m.side
            let printSide = m.printSide
            let lang = model.language
            let panelOffsetY = (m.shutter - m.wheel) / 2 + m.gapLCD - m.pt(12)   // bottom edge 12 above the LCD
            let sideGap = max(0, (geo.size.width - m.shutter) / 2)               // screen edge → shutter, one side
            ZStack(alignment: .top) {
                Leather(metrics: m)
                VStack(spacing: 0) {
                    // title band: just "snap", right-aligned, 3 pt inside the print's right edge
                    (Text("snap").foregroundStyle(Theme.title(scheme))
                     + Text(UIDevice.current.userInterfaceIdiom == .pad ? ".afterworkphotos" : "").foregroundStyle(scheme == .dark ? .white : .black))
                        .font(.system(size: m.pt(17), weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .trailing).frame(height: m.titleHeight)
                        .padding(.trailing, side + m.pt(3)).padding(.leading, side)
                        .padding(.top, m.titleTop)
                    // the print — the captured photo stays up, above the live viewfinder,
                    // from the shutter release until retake or a finished post
                    ZStack {
                        PreviewView(layer: model.camera.previewLayer)
                        if !model.isLive && model.preview == nil {
                            Image("LaunchIcon").resizable().scaledToFill()
                        }
                        if let image = model.preview {
                            Image(uiImage: image).resizable().scaledToFill()
                        }
                    }
                    .frame(width: printSide, height: printSide)
                    .clipShape(RoundedRectangle(cornerRadius: m.pt(6)))
                    .overlay(RoundedRectangle(cornerRadius: m.pt(6)).stroke(Theme.shade(scheme).opacity(0.35), lineWidth: 1))
                    .overlay(                                                // letterpress: top and left wall in shadow
                        RoundedRectangle(cornerRadius: m.pt(6))
                            .inset(by: 0.5)
                            .stroke(Theme.shade(scheme).opacity(0.45), lineWidth: 3)
                            .blur(radius: 3)
                            .mask(RoundedRectangle(cornerRadius: m.pt(6)))
                            .mask(LinearGradient(colors: [.black, .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .shadow(color: Theme.edgeLight(scheme), radius: 0, y: 1)
                    .padding(.top, m.printTop - m.titleTop - m.titleHeight)
                    LogoView(size: m.logoSize).padding(.top, m.gapLogo)
                    ZStack {
                        ShutterButton(size: m.shutter, metrics: m, locked: model.shutterLocked, breathing: model.shutterBreathing) { model.shoot() }
                        HStack {
                            if panelOnLeft {
                                ControlPanel(count: model.names.count,
                                             selection: Binding(get: { model.nameIndex }, set: { model.select($0) }),
                                             enabled: model.controlsEnabled, metrics: m, mirrored: true,
                                             onCenter: { model.fetchNames() })
                                    .padding(.leading, side)
                                Spacer()
                            } else {
                                Spacer()
                                ControlPanel(count: model.names.count,
                                             selection: Binding(get: { model.nameIndex }, set: { model.select($0) }),
                                             enabled: model.controlsEnabled, metrics: m, mirrored: false,
                                             onCenter: { model.fetchNames() })
                                    .padding(.trailing, side)
                            }
                        }
                        .offset(y: panelOffsetY)
                        // An empty-body tap target beside the shutter, on the side
                        // WITHOUT the panel, moves the panel to the other side.
                        HStack(spacing: 0) {
                            if panelOnLeft {
                                Spacer()
                                Color.clear.frame(width: sideGap).contentShape(Rectangle())
                                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { panelOnLeft.toggle() } }
                            } else {
                                Color.clear.frame(width: sideGap).contentShape(Rectangle())
                                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { panelOnLeft.toggle() } }
                                Spacer()
                            }
                        }
                        .frame(height: m.wheel)
                        .offset(y: panelOffsetY)
                    }
                    .padding(.top, m.gapShutter)
                    LCDView(rows: [LCDRow(id: .name, value: model.nameRow),
                                   LCDRow(id: .loc, value: model.place ?? Strings.t(.empty, lang)),
                                   LCDRow(id: .date, value: model.date ?? Strings.t(.empty, lang))],
                            invertedRow: model.showIndex ? .name : nil,
                            sign: model.sign, signTwitching: model.phase == .failed,
                            language: lang, metrics: m, enabled: model.controlsEnabled, onNameSwipe: { model.step($0) })
                        .padding(.horizontal, side).padding(.top, m.gapLCD)
                    Spacer(minLength: 0)
                }
                VStack { Spacer()
                    HStack {
                        SlideView(label: Strings.t(.retake, lang), colour: Theme.red, mirrored: true, enabled: model.controlsEnabled, metrics: m) { model.retake() }
                        Spacer()
                        SlideView(label: Strings.t(model.phase == .failed ? .retry : .post, lang), colour: Theme.green, mirrored: false, enabled: model.controlsEnabled, metrics: m) { model.post() }
                    }
                    .padding(.horizontal, side).padding(.bottom, m.slideBottom)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .animation(.easeInOut(duration: 0.3), value: scheme)   // cross-fade leather/panel/title/LCD on appearance change
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}
