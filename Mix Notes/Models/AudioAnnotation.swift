import Foundation

struct AudioAnnotation: Identifiable, Codable {
    let id: UUID
    let timestamp: TimeInterval
    let type: AnnotationType
    let customText: String?
    
    init(id: UUID = UUID(), timestamp: TimeInterval, type: AnnotationType, customText: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.customText = customText
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