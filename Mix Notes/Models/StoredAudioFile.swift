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
        self.id = UUID()
        self.fileName = fileName
        self.originalURL = originalURL.absoluteString
        self.storedURL = storedURL.absoluteString
        self.dateAdded = Date()
        self.duration = duration
    }
    
    var displayName: String {
        return fileName.replacingOccurrences(of: "_", with: " ")
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
}
