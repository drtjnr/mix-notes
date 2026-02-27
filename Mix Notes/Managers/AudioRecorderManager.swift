import Foundation
import AVFoundation

class AudioRecorderManager: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published private(set) var recordingURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private static let maxDuration: TimeInterval = 60

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsDirectory.appendingPathComponent("AudioRecordings")

        if !FileManager.default.fileExists(atPath: recordingsDir.path) {
            try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        }

        let fileName = "recording_\(UUID().uuidString).m4a"
        let fileURL = recordingsDir.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.record()
        recordingURL = fileURL
        isRecording = true
        recordingDuration = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.recordingDuration = self.audioRecorder?.currentTime ?? 0
            if self.recordingDuration >= Self.maxDuration {
                _ = self.stopRecording()
            }
        }
    }

    func stopRecording() -> URL? {
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
        isRecording = false
        let url = recordingURL
        audioRecorder = nil
        restorePlaybackSession()
        return url
    }

    func cancelRecording() {
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
        isRecording = false

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        audioRecorder = nil
        restorePlaybackSession()
    }

    private func restorePlaybackSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    static func fileName(from url: URL) -> String {
        url.lastPathComponent
    }

    static func deleteRecording(fileName: String) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("AudioRecordings").appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
