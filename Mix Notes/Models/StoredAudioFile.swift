//
//  StoredAudioFile.swift
//  Mix Notes
//
//  Created by David Thomas on 1/4/25.
//

import Foundation

struct StoredAudioFile: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let originalURL: String
    let storedURL: String
    let dateAdded: Date
    let duration: TimeInterval

    init(fileName: String, originalURL: URL, storedURL: URL, duration: TimeInterval) {
        self.init(
            id: UUID(),
            fileName: fileName,
            originalURL: originalURL.absoluteString,
            storedURL: StoredAudioFile.relativePath(for: storedURL),
            dateAdded: Date(),
            duration: duration
        )
    }

    private init(id: UUID, fileName: String, originalURL: String, storedURL: String, dateAdded: Date, duration: TimeInterval) {
        self.id = id
        self.fileName = fileName
        self.originalURL = originalURL
        self.storedURL = storedURL
        self.dateAdded = dateAdded
        self.duration = duration
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case fileName
        case originalURL
        case storedURL
        case storedRelativePath
        case dateAdded
        case duration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decode(UUID.self, forKey: .id)
        let fileName = try container.decode(String.self, forKey: .fileName)
        let originalURL = try container.decodeIfPresent(String.self, forKey: .originalURL) ?? ""
        let dateAdded = try container.decodeIfPresent(Date.self, forKey: .dateAdded) ?? Date()
        let duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0

        if let relativePath = try container.decodeIfPresent(String.self, forKey: .storedRelativePath) {
            self.init(
                id: id,
                fileName: fileName,
                originalURL: originalURL,
                storedURL: relativePath,
                dateAdded: dateAdded,
                duration: duration
            )
        } else {
            let legacyString = try container.decode(String.self, forKey: .storedURL)
            self.init(
                id: id,
                fileName: fileName,
                originalURL: originalURL,
                storedURL: StoredAudioFile.relativePath(fromLegacy: legacyString),
                dateAdded: dateAdded,
                duration: duration
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(originalURL, forKey: .originalURL)
        try container.encode(storedURL, forKey: .storedRelativePath)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(duration, forKey: .duration)
    }

    var displayName: String {
        fileName.replacingOccurrences(of: "_", with: " ")
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateAdded)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var resolvedStoredFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(storedURL)
    }

    private static func relativePath(for url: URL) -> String {
        let pathComponents = url.pathComponents

        if let documentsIndex = pathComponents.firstIndex(of: "Documents"),
           documentsIndex < pathComponents.endIndex - 1 {
            let relativeComponents = pathComponents[(documentsIndex + 1)...]
            return relativeComponents.joined(separator: "/")
        }

        if let audioFilesIndex = pathComponents.firstIndex(of: "AudioFiles") {
            let relativeComponents = pathComponents[audioFilesIndex...]
            return relativeComponents.joined(separator: "/")
        }

        return url.lastPathComponent
    }

    private static func relativePath(fromLegacy legacyString: String) -> String {
        if let legacyURL = URL(string: legacyString), legacyURL.scheme != nil {
            return relativePath(for: legacyURL)
        }

        if legacyString.hasPrefix("/") {
            return relativePath(for: URL(fileURLWithPath: legacyString))
        }

        return legacyString
    }
}
