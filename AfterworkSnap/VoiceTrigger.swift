import Foundation
import Speech
import AVFoundation

/// Listens for the spoken word "snap" (or its German equivalent
/// "schnapp") and fires the shutter hands-free. On-device recognition
/// only, when the phone supports it. Silently does nothing if either
/// permission is denied — the physical shutter button still works.
///
/// Every `AVAudioSession`/`AVAudioEngine` call (both are documented "hang
/// risks" if called on the main thread) runs on `audioQueue`, a private
/// serial queue — never on the main actor. `start()`/`stop()` just
/// dispatch onto it and return immediately; the two authorizations are
/// requested from whatever thread calls `start()` (they're async system
/// APIs, not a hang risk). Only the final `onTrigger` call hops back to
/// the main actor.
nonisolated final class VoiceTrigger: NSObject, @unchecked Sendable {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private let audioQueue = DispatchQueue(label: "co.msmr.afterworksnap.voice")
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var lastTrigger: Date?
    private var authorized: Bool?          // nil = not yet asked
    private var listening = false
    /// Fired on the main actor when "snap"/"schnapp" is heard.
    var onTrigger: (() -> Void)?

    func start() {
        if let authorized {
            guard authorized else { return }
            audioQueue.async { [weak self] in self?.beginListening() }
            return
        }
        requestAuthorizations { [weak self] granted in
            guard let self else { return }
            self.authorized = granted
            guard granted else { return }
            self.audioQueue.async { [weak self] in self?.beginListening() }
        }
    }

    func stop() {
        audioQueue.async { [weak self] in self?.stopListening() }
    }

    private func requestAuthorizations(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            guard speechStatus == .authorized else { completion(false); return }
            AVAudioApplication.requestRecordPermission { micGranted in
                completion(micGranted)
            }
        }
    }

    // MARK: - Everything below here only ever runs on `audioQueue`.

    /// Configures the audio session and starts the engine + recognition
    /// task. Never touches the `AVCaptureSession` — the capture session
    /// and this session configuration must coexist; this is set up
    /// *before* the audio engine starts, not the other way round.
    private func beginListening() {
        guard !listening else { return }
        guard let recognizer, recognizer.isAvailable else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            // `.default` (not `.measurement`) plus the Bluetooth options,
            // so recognition and the UI sounds both follow whatever route
            // is actually active (speaker, or a connected BT headset)
            // instead of forcing the speaker while BT is connected.
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.allowBluetoothA2DP, .allowBluetoothHFP, .duckOthers, .defaultToSpeaker])
            // While recording, iOS silences ALL haptics (and system
            // sounds) unless this is set — the always-on "snap" listener
            // would otherwise mute the shutter's clicks and the drum's
            // ticks. Best effort: listening must not die over feel.
            try? session.setAllowHapticsAndSystemSoundsDuringRecording(true)
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

    private func stopListening() {
        listening = false
        task?.cancel(); task = nil
        request?.endAudio(); request = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startRecognitionTask(recognizer: SFSpeechRecognizer) {
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        request = req
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            // This completion runs on an internal Speech-framework queue,
            // not necessarily `audioQueue` — hop there before touching any
            // shared state, the request, or the engine.
            guard let self else { return }
            self.audioQueue.async {
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
}
