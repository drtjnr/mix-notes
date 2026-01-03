import SwiftUI
import MediaPlayer
import UIKit

struct ABMusicLibrarySection: View {
    @ObservedObject var libraryManager: LibraryManager
    let slotForSong: (LibrarySong) -> ABAudioAnnotationViewModel.AudioSlot?
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
                    .font(MixNotesDesign.sfItalic(14))
                    .foregroundColor(MixNotesDesign.warmGray)
                    .padding(.vertical, 4)
                    .listRowBackground(MixNotesDesign.cream)
            case .notDetermined:
                requestAccessContent
            @unknown default:
                Text("Music library access is unavailable.")
                    .font(MixNotesDesign.sfItalic(14))
                    .foregroundColor(MixNotesDesign.warmGray)
                    .padding(.vertical, 4)
                    .listRowBackground(MixNotesDesign.cream)
            }
        } header: {
            HStack {
                Text("Recently Added Songs")
                    .font(MixNotesDesign.sfFont(17, weight: .medium))
                    .foregroundColor(MixNotesDesign.charcoal)
                    .textCase(nil)
                Spacer()
                if libraryManager.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.7, anchor: .center)
                        .tint(MixNotesDesign.charcoal)
                } else if let lastUpdated = libraryManager.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(MixNotesDesign.sfFont(12))
                        .foregroundColor(MixNotesDesign.warmGray)
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
                        .tint(MixNotesDesign.charcoal)
                    Spacer()
                }
                .listRowBackground(MixNotesDesign.cream)
            } else {
                Text("No on-device songs were found in your Music library.")
                    .font(MixNotesDesign.sfItalic(14))
                    .foregroundColor(MixNotesDesign.warmGray)
                    .padding(.vertical, 4)
                    .listRowBackground(MixNotesDesign.cream)
            }
        } else {
            ForEach(libraryManager.songs) { song in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onSelectSong(song)
                    }
                } label: {
                    let slot = slotForSong(song)
                    MusicLibraryRow(song: song)
                        .padding(.leading, slot == nil ? 0 : 28)
                        .overlay(alignment: .leading) {
                            if let slot {
                                selectionBadge(for: slot)
                            }
                        }
                }
                .buttonStyle(.plain)
                .listRowBackground(MixNotesDesign.cream)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: slotForSong(song))
            }
        }
    }

    @ViewBuilder
    private var accessDeniedContent: some View {
        Text("ab cannot access your Music library. Enable access in Settings to browse your songs.")
            .font(MixNotesDesign.sfItalic(14))
            .foregroundColor(MixNotesDesign.warmGray)
            .padding(.vertical, 4)
            .listRowBackground(MixNotesDesign.cream)
        Button {
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                openURL(settingsURL)
            }
        } label: {
            Text("Open Settings")
                .font(MixNotesDesign.sfFont(15))
                .foregroundColor(MixNotesDesign.charcoal)
        }
        .buttonStyle(.plain)
        .listRowBackground(MixNotesDesign.cream)
    }

    @ViewBuilder
    private var requestAccessContent: some View {
        Text("Allow ab to access your on-device Music library to play recently added songs.")
            .font(MixNotesDesign.sfItalic(14))
            .foregroundColor(MixNotesDesign.warmGray)
            .padding(.vertical, 4)
            .listRowBackground(MixNotesDesign.cream)
        Button {
            libraryManager.requestAuthorization()
        } label: {
            Text("Allow Music Library Access")
                .font(MixNotesDesign.sfFont(15))
                .foregroundColor(MixNotesDesign.charcoal)
        }
        .buttonStyle(.plain)
        .listRowBackground(MixNotesDesign.cream)
    }
}

private func selectionBadge(for slot: ABAudioAnnotationViewModel.AudioSlot) -> some View {
    Text(slot.displayLabel)
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(MixNotesDesign.cream)
        .frame(width: 22, height: 22)
        .background(Circle().fill(MixNotesDesign.charcoal))
}

private struct MusicLibraryRow: View {
    let song: LibrarySong

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(song.displayTitle)
                    .font(MixNotesDesign.sfFont(16, weight: .medium))
                    .foregroundColor(MixNotesDesign.charcoal)
                Text(song.displaySubtitle)
                    .font(MixNotesDesign.sfFont(13))
                    .foregroundColor(MixNotesDesign.warmGray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formattedDuration(song.duration))
                    .font(MixNotesDesign.sfFont(13))
                    .foregroundColor(MixNotesDesign.warmGray)
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
