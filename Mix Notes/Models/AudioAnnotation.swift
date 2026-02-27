import Foundation

struct AudioAnnotation: Identifiable, Codable {
    let id: UUID
    let timestamp: TimeInterval
    let type: AnnotationType
    let customText: String?
    let audioRecordingFileName: String?

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        type: AnnotationType,
        customText: String? = nil,
        audioRecordingFileName: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.customText = customText
        self.audioRecordingFileName = audioRecordingFileName
    }

    var resolvedAudioRecordingURL: URL? {
        guard let fileName = audioRecordingFileName else { return nil }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("AudioRecordings").appendingPathComponent(fileName)
    }
}

enum AnnotationType: String, Codable, CaseIterable {
    case tooLoud = "Too Loud"
    case tuning = "Tuning"
    case glitch = "Glitch"
    case tooQuiet = "Too Quiet"
    case timing = "Timing"
    case custom = "Custom"
}
