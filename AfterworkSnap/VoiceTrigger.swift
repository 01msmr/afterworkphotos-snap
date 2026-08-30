import Foundation
import Speech
import AVFoundation

/// Listens for the spoken word "snap" (or its German equivalent
/// "schnapp") and fires the shutter hands-free. On-device recognition
/// only, when the phone supports it. Silently does nothing if either
/// permission is denied — the physical shutter button still works.
nonisolated final class VoiceTrigger: NSObject, @unchecked Sendable {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var lastTrigger: Date?
    private var authorized: Bool?          // nil = not yet asked
    private var listening = false
    /// Fired on the main actor when "snap"/"schnapp" is heard.
    var onTrigger: (() -> Void)?

    func start() {
        guard !listening else { return }
        if let authorized {
            guard authorized else { return }
            beginListening()
            return
        }
        requestAuthorizations { [weak self] granted in
            guard let self else { return }
            self.authorized = granted
            guard granted else { return }
            self.beginListening()
        }
    }

    func stop() {
        listening = false
        task?.cancel(); task = nil
        request?.endAudio(); request = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestAuthorizations(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            guard speechStatus == .authorized else { completion(false); return }
            AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                completion(micGranted)
            }
        }
    }

    /// Configures the audio session and starts the engine + recognition
    /// task. Never touches the `AVCaptureSession` — the capture session
    /// and this session-configuration call must coexist; this is set up
    /// *before* the audio engine starts, not the other way round.
    private func beginListening() {
        guard let recognizer, recognizer.isAvailable else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers])
            try session.setActive(true)
        } catch { return }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        audioEngine.prepare()
        do { try audioEngine.start() } catch { return }

        listening = true
        startRecognitionTask(recognizer: recognizer)
    }

    private func startRecognitionTask(recognizer: SFSpeechRecognizer) {
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        request = req
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let last = result.bestTranscription.formattedString
                    .split(separator: " ").last?.lowercased()
                if last == "snap" || last == "schnapp" {
                    let now = Date()
                    if self.lastTrigger == nil || now.timeIntervalSince(self.lastTrigger!) >= 1.5 {
                        self.lastTrigger = now
                        Task { @MainActor in self.onTrigger?() }
                        // Restart the recognition task (not the engine/tap)
                        // so the same word is never re-matched.
                        self.task?.cancel()
                        self.request?.endAudio()
                        self.startRecognitionTask(recognizer: recognizer)
                    }
                }
            }
            if error != nil, self.listening {
                self.task?.cancel(); self.task = nil
                self.request?.endAudio(); self.request = nil
                self.startRecognitionTask(recognizer: recognizer)
            }
        }
    }
}
