@preconcurrency import AVFoundation

enum CaptureError: LocalizedError {
    case noCamera, cannotConfigure, noData
    var errorDescription: String? {
        switch self {
        case .noCamera:        "No wide-angle camera available."
        case .cannotConfigure: "Could not configure the capture session."
        case .noData:          "Capture produced no image data."
        }
    }
}

/// Plain AVCaptureSession: no flash, no deferred delivery, no depth or mattes.
/// Those are Camera.app features, not system behaviour.
nonisolated final class SnapSession: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "snap.session")
    private var completion: ((Result<Data, Error>) -> Void)?

    func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CaptureError.noCamera
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input), session.canAddOutput(output) else { throw CaptureError.cannotConfigure }
        session.addInput(input)
        session.addOutput(output)
        // Ceiling for per-photo prioritization; .quality enables the
        // multi-frame fusion passes (Deep Fusion, extended low light).
        output.maxPhotoQualityPrioritization = .quality
        output.isFastCapturePrioritizationEnabled = false
        output.isDepthDataDeliveryEnabled = false
        output.isPortraitEffectsMatteDeliveryEnabled = false
        output.enabledSemanticSegmentationMatteTypes = []
        // Without this, fileDataRepresentation() may be a proxy, not the final image.
        output.isAutoDeferredPhotoDeliveryEnabled = false
    }

    func start() { queue.async { [session] in if !session.isRunning { session.startRunning() } } }
    func stop()  { queue.async { [session] in if  session.isRunning { session.stopRunning() } } }

    /// Full-sensor JPEG, delivered on the main queue. Not yet cropped.
    func capture(_ completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.flashMode = .off
        settings.photoQualityPrioritization = .quality
        settings.isAutoRedEyeReductionEnabled = false
        settings.isDepthDataDeliveryEnabled = false
        settings.isPortraitEffectsMatteDeliveryEnabled = false
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let result: Result<Data, Error>
        if let error { result = .failure(error) }
        else if let data = photo.fileDataRepresentation() { result = .success(data) }
        else { result = .failure(CaptureError.noData) }
        DispatchQueue.main.async { self.completion?(result); self.completion = nil }
    }
}
