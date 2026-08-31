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
///
/// Where the hardware supports it (`AVCaptureMultiCamSession`), the front
/// camera runs alongside the back one, mirrored, as the chrome shutter
/// button's real reflection — smallest multi-cam format, preview only,
/// never captured. Multi-cam has no presets, so the back camera keeps a
/// multi-cam-capable format and the photo output's ceiling is raised to
/// that format's largest photo size by hand. Without multi-cam support
/// everything behaves exactly as before and `frontPreviewLayer` is nil.
nonisolated final class SnapSession: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session: AVCaptureSession
    let previewLayer: AVCaptureVideoPreviewLayer
    /// The front camera, mirrored — the shutter button's reflection; nil
    /// without multi-cam support (the button draws a silhouette instead).
    let frontPreviewLayer: AVCaptureVideoPreviewLayer?
    private let multiCam: Bool
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "snap.session")
    private var completion: ((Result<Data, Error>) -> Void)?
    private var startObserver: NSObjectProtocol?
    /// Fired (off the main thread) the first time the session actually starts running.
    var onDidStartRunning: (() -> Void)?

    override init() {
        multiCam = AVCaptureMultiCamSession.isMultiCamSupported
        session = multiCam ? AVCaptureMultiCamSession() : AVCaptureSession()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        frontPreviewLayer = multiCam ? AVCaptureVideoPreviewLayer(sessionWithNoConnection: session) : nil
        super.init()
        previewLayer.videoGravity = .resizeAspectFill
        frontPreviewLayer?.videoGravity = .resizeAspectFill
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
        if !multiCam { session.sessionPreset = .photo }   // multi-cam sessions have no presets
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
        if multiCam {
            // Stand in for the missing .photo preset: a multi-cam-capable
            // back format, and the photo ceiling raised to its largest size.
            if !device.activeFormat.isMultiCamSupported {
                guard let best = device.formats.filter({ $0.isMultiCamSupported })
                    .max(by: { photoArea($0) < photoArea($1) }) else { throw CaptureError.cannotConfigure }
                try device.lockForConfiguration()
                device.activeFormat = best
                device.unlockForConfiguration()
            }
            if let dims = largestPhotoDimensions(of: device.activeFormat) {
                output.maxPhotoDimensions = dims
            }
        }
        // Ceiling for per-photo prioritization; .quality enables the
        // multi-frame fusion passes (Deep Fusion, extended low light).
        output.maxPhotoQualityPrioritization = .quality
        output.isFastCapturePrioritizationEnabled = false
        output.isDepthDataDeliveryEnabled = false
        output.isPortraitEffectsMatteDeliveryEnabled = false
        output.enabledSemanticSegmentationMatteTypes = []
        // Without this, fileDataRepresentation() may be a proxy, not the final image.
        output.isAutoDeferredPhotoDeliveryEnabled = false
        if multiCam { addFrontReflection() }
    }

    private func largestPhotoDimensions(of format: AVCaptureDevice.Format) -> CMVideoDimensions? {
        format.supportedMaxPhotoDimensions.max { Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) }
    }
    private func photoArea(_ format: AVCaptureDevice.Format) -> Int {
        guard let d = largestPhotoDimensions(of: format) else { return 0 }
        return Int(d.width) * Int(d.height)
    }
    private func videoArea(_ format: AVCaptureDevice.Format) -> Int {
        let d = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        return Int(d.width) * Int(d.height)
    }

    /// The front camera into the button, best effort — any failure just
    /// leaves the drawn silhouette; the back camera is never touched.
    private func addFrontReflection() {
        guard let frontPreviewLayer,
              let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return }
        // The reflection is 15 mm wide: the smallest multi-cam format is
        // plenty, and the cheapest to run.
        if let small = front.formats.filter({ $0.isMultiCamSupported })
            .min(by: { videoArea($0) < videoArea($1) }) {
            do { try front.lockForConfiguration(); front.activeFormat = small; front.unlockForConfiguration() }
            catch { return }
        } else { return }
        guard let input = try? AVCaptureDeviceInput(device: front), session.canAddInput(input) else { return }
        session.addInputWithNoConnections(input)
        guard let port = input.ports(for: .video, sourceDeviceType: front.deviceType, sourceDevicePosition: .front).first else { return }
        let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: frontPreviewLayer)
        guard session.canAddConnection(connection) else { return }
        session.addConnection(connection)   // mirroring stays automatic — a mirror mirrors
        if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }   // portrait-only app
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
        if multiCam { settings.maxPhotoDimensions = output.maxPhotoDimensions }
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
