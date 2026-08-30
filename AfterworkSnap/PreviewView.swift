import SwiftUI
import AVFoundation

/// Installs the session's own preview layer as a sublayer, so freezing it
/// (see `SnapSession.freezePreview`) freezes exactly what's on screen.
struct PreviewView: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    final class View: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }

    func makeUIView(context: Context) -> View {
        let v = View()
        v.previewLayer = layer
        v.layer.addSublayer(layer)
        return v
    }
    func updateUIView(_ uiView: View, context: Context) {
        uiView.previewLayer?.frame = uiView.bounds
    }
}
