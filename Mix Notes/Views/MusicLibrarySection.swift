import SwiftUI
import MediaPlayer
import UIKit

struct MusicLibrarySection: View {
    @ObservedObject var libraryManager: LibraryManager
    let onSelectSong: (LibrarySong) -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            switch libraryManager.authorizationStatus {
            case .authorized:
                authorizedContent
            case .denied:
                accessDeniedContent
            case .restricted:
                Text("Music library access is restricted on this device.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            case .notDetermined:
                requestAccessContent
            @unknown default:
                Text("Music library access is unavailable.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
        } header: {
            HStack {
                Text("Recently Added Songs")
                    .font(.headline)
                Spacer()
                if libraryManager.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.75, anchor: .center)
                } else if let lastUpdated = libraryManager.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var authorizedContent: some View {
        if libraryManager.songs.isEmpty {
            if libraryManager.isRefreshing {
                HStack {
                    Spacer()
                    ProgressView("Loading songs…")
                        .progressViewStyle(.circular)
                    Spacer()
                }
            } else {
                Text("No on-device songs were found in your Music library.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
        } else {
            ForEach(libraryManager.songs) { song in
                Button {
                    onSelectSong(song)
                } label: {
                    MusicLibraryRow(song: song)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var accessDeniedContent: some View {
        Text("Mix Notes cannot access your Music library. Enable access in Settings to browse your songs.")
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding(.vertical, 4)
        Button("Open Settings") {
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                openURL(settingsURL)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var requestAccessContent: some View {
        Text("Allow Mix Notes to access your on-device Music library to play recently added songs.")
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding(.vertical, 4)
        Button("Allow Music Library Access") {
            libraryManager.requestAuthorization()
        }
        .buttonStyle(.plain)
    }
}

private struct MusicLibraryRow: View {
    let song: LibrarySong

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.displayTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(song.displaySubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Added: \(formattedDate(song.dateAdded))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formattedDuration(song.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private func formattedDuration(_ duration: TimeInterval) -> String {
    guard duration.isFinite && !duration.isNaN else {
        return "--:--"
    }
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%02d:%02d", minutes, seconds)
}
