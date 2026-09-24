import SwiftUI
import PhotosUI
import SnapCore

struct ContentView: View {
    @State private var model = AppModel()
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("panelOnLeft") private var panelOnLeft = false
    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        GeometryReader { geo in
            let m = Metrics(width: geo.size.width, height: geo.size.height)
            let side = m.side
            let printSide = m.printSide
            let lang = model.language
            // The panel hangs from the LCD: its top edge sits 12 pt below
            // the LCD's bottom, mirroring (negated) the old bottom-aligned
            // formula, since the LCD is now above the shutter row, not below.
            let panelOffsetY = -((m.shutter - m.wheel) / 2 + m.gapLCD - m.pt(12))
            let sideGap = max(0, (geo.size.width - m.shutter) / 2)               // screen edge → shutter, one side
            // Both slides sized from every word either might show, in both
            // languages: always the same width, so the logo sits dead centre.
            let slideWords = [Language.en, .de].flatMap { l in [Strings.Key.retake, .post, .retry].map { Strings.t($0, l) } }
            ZStack(alignment: .top) {
                Leather(metrics: m)
                VStack(spacing: 0) {
                    // no title band any more — the print rises alone over the leather
                    // the print — the captured photo stays up, above the live viewfinder,
                    // from the shutter release until retake or a finished post
                    ZStack {
                        PreviewView(layer: model.camera.previewLayer)
                        if !model.isLive && model.preview == nil {
                            Image("LaunchIcon").resizable().scaledToFill()
                        }
                        if let image = model.preview {
                            Image(uiImage: image).resizable().scaledToFill()
                                .offset(x: model.ejecting ? printSide : 0)   // the print pushes out to the right, revealing the live view
                                .animation(.easeIn(duration: AppModel.ejectDuration), value: model.ejecting)
                        }
                    }
                    .overlay(Color.white.opacity(0.045))                     // the matte screen's faint milk
                    .saturation(0.90).contrast(0.94)                         // ground glass, not gloss
                    .frame(width: printSide, height: printSide)
                    // A library photo wears the Upload badge — on screen only,
                    // never in the file; above the matte, leaving with the print.
                    .overlay(alignment: .bottomLeading) {
                        if model.picked && model.preview != nil {
                            UploadLabel(text: Strings.t(.upload, lang), metrics: m, size: 12 * 1.3)   // 30 % up
                                .padding(.horizontal, m.pt(8 * 1.3)).padding(.vertical, m.pt(4 * 1.3))
                                .background(Theme.yellow.opacity(0.5))
                                .padding(m.pt(10))
                                .offset(x: model.ejecting ? printSide : 0)
                                .animation(.easeIn(duration: AppModel.ejectDuration), value: model.ejecting)
                        }
                    }
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
                    .padding(.top, m.printTop)
                    // The LCD, directly below the print now (24 pt gap).
                    LCDView(rows: [LCDRow(id: .name, value: model.nameRow),
                                   LCDRow(id: .loc, value: model.place ?? Strings.t(.empty, lang)),
                                   LCDRow(id: .date, value: model.date ?? Strings.t(.empty, lang))],
                            invertedRow: model.showIndex ? .name : nil,
                            sign: model.sign, signTwitching: model.phase == .failed,
                            language: lang, metrics: m, enabled: model.controlsEnabled, onNameSwipe: { model.step($0) })
                        .padding(.horizontal, side).padding(.top, m.gapLogo)
                    // The shutter row: shutter centred; the control panel
                    // hangs from the LCD's bottom (see panelOffsetY above).
                    ZStack {
                        ShutterButton(size: m.shutter, metrics: m, locked: model.shutterLocked, reflection: model.camera.frontPreviewLayer, onTouch: { model.shutterHeld = $0; if $0 { Sounds.wake() } }) { model.shoot() }
                        HStack {
                            if panelOnLeft {
                                ControlPanel(count: model.names.count,
                                             selection: Binding(get: { model.nameIndex }, set: { model.select($0) }),
                                             enabled: model.controlsEnabled, metrics: m, mirrored: true,
                                             onCenter: { model.fetchNames() })
                                    .opacity(model.preview == nil ? 0.7 : 1)   // the panel at 70 % while the print is empty
                                    .padding(.leading, side)
                                Spacer()
                            } else {
                                Spacer()
                                ControlPanel(count: model.names.count,
                                             selection: Binding(get: { model.nameIndex }, set: { model.select($0) }),
                                             enabled: model.controlsEnabled, metrics: m, mirrored: false,
                                             onCenter: { model.fetchNames() })
                                    .opacity(model.preview == nil ? 0.7 : 1)   // the panel at 70 % while the print is empty
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
                    .padding(.top, m.gapLCD)
                    Spacer(minLength: 0)
                }
                // Bottom row: retake — Snap (centred between them, vertically
                // centred on the slides) — post.
                VStack(spacing: 0) { Spacer()
                    // The Upload button, directly above the bottom row: a
                    // library photo instead of a shot, while the print is empty.
                    // Square, 80 % of the shutter's width; its label bold and 30 % up.
                    PhotosPicker(selection: $pickedItem, matching: .images, preferredItemEncoding: .current) {
                        UploadLabel(text: Strings.t(.upload, lang), metrics: m, size: 12 * 1.3, weight: .bold)
                            .frame(width: m.shutter * 0.8, height: m.shutter * 0.8)
                            .background(Theme.yellow.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: m.shutter * 0.8 * 0.08))
                    }
                    .simultaneousGesture(TapGesture().onEnded { Sounds.wake() })
                    .disabled(!model.canPick)
                    .opacity(model.canPick ? 1 : 0.4)
                    .padding(.bottom, m.pt(10))
                    HStack {
                        SlideView(label: Strings.t(.retake, lang), colour: Theme.red, mirrored: true, enabled: model.controlsEnabled, metrics: m, sizingLabels: slideWords, fireSound: "zip") { model.retake() }
                        Spacer()
                        LogoView(size: m.logoSize)
                            .onTapGesture { model.demoPost() }   // the demo: the whole post experience, nothing sent
                        Spacer()
                        SlideView(label: Strings.t(model.phase == .failed ? .retry : .post, lang), colour: Theme.green, mirrored: false, enabled: model.controlsEnabled, metrics: m, sizingLabels: slideWords, fireSound: nil) { model.post() }
                    }
                    .padding(.horizontal, side).padding(.bottom, m.slideBottom)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .animation(.easeInOut(duration: 0.3), value: scheme)   // cross-fade leather/panel/LCD on appearance change
        .onChange(of: pickedItem) {
            guard let item = pickedItem else { return }
            pickedItem = nil
            Task {
                // .current encoding: the original file, EXIF and GPS intact.
                if let data = try? await item.loadTransferable(type: Data.self) {
                    model.usePicked(data)
                } else {
                    Sounds.play("knock")   // the photo didn't come
                }
            }
        }
        .onOpenURL { _ in model.takeShared() }   // afterworksnap://picked, from the share extension
        .onChange(of: scenePhase) { if scenePhase == .active { model.takeShared() } }   // opened by hand after a share
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

/// "Upload", dark on 50 % yellow — the button's face (bold, 30 % up) and
/// the print's badge (the slides' label type); the caller sizes the rectangle.
private struct UploadLabel: View {
    let text: String
    let metrics: Metrics
    var size: CGFloat = 12
    var weight: Font.Weight = .semibold
    var body: some View {
        Text(text)
            .font(.system(size: metrics.pt(size), weight: weight))
            .foregroundStyle(.black.opacity(0.85))
    }
}
