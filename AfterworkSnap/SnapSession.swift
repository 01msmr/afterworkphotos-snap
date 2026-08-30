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
    let previewLayer: AVCaptureVideoPreviewLayer
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "snap.session")
    private var completion: ((Result<Data, Error>) -> Void)?
    private var startObserver: NSObjectProtocol?
    /// Fired (off the main thread) the first time the session actually starts running.
    var onDidStartRunning: (() -> Void)?

    override init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init()
        previewLayer.videoGravity = .resizeAspectFill
        startObserver = NotificationCenter.default.addObserver(forName: AVCaptureSession.didStartRunningNotification, object: session, queue: nil) { [weak self] _ in
            self?.onDidStartRunning?()
        }
    }
    deinit { if let startObserver { NotificationCenter.default.removeObserver(startObserver) } }

    func configure() throws {
        #if DEBUG
        print("t+\(msSinceLaunch()) ms: session queue, before beginConfiguration")
        #endif
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        #if DEBUG
        let deviceStart = Date()
        #endif
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CaptureError.noCamera
        }
        #if DEBUG
        // Notes, doesn't gate anything: AVCaptureDevice.default(_:for:position:)
        // is itself a synchronous, on-queue call — if device discovery were
        // ever slow, it would show up right here as a large gap between this
        // line and "before beginConfiguration" above.
        print("t+\(msSinceLaunch()) ms: device discovery took \(Int(Date().timeIntervalSince(deviceStart) * 1000)) ms")
        #endif
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

    /// Configuration and `startRunning()` are both blocking calls — do the
    /// whole thing on the session's own queue, never the main thread, and
    /// call back on main with the result.
    func configureAndStart(completion: @escaping @Sendable (Error?) -> Void) {
        queue.async { [self] in
            do {
                try configure()
                #if DEBUG
                print("t+\(msSinceLaunch()) ms: after commitConfiguration")
                #endif
                if !session.isRunning { session.startRunning() }
                #if DEBUG
                print("t+\(msSinceLaunch()) ms: after startRunning returns")
                #endif
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }

    /// Freezes (or unfreezes) the viewfinder on its last delivered frame,
    /// for the instant it takes the real capture to arrive — the preview
    /// layer's connection just stops accepting new frames.
    func freezePreview(_ frozen: Bool) {
        previewLayer.connection?.isEnabled = !frozen
    }

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
