import SwiftUI
import AVFoundation
import QuartzCore

/// Installs the session's own preview layer as a sublayer, so freezing it
/// (see `SnapSession.freezePreview`) freezes exactly what's on screen.
struct PreviewView: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    final class View: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?
        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer?.frame = bounds
            CATransaction.commit()
        }
    }

    func makeUIView(context: Context) -> View {
        let v = View()
        v.previewLayer = layer
        v.layer.addSublayer(layer)
        return v
    }
    func updateUIView(_ uiView: View, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        uiView.previewLayer?.frame = uiView.bounds
        CATransaction.commit()
    }
}
