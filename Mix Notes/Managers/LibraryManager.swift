import Foundation
import MediaPlayer
import AVFoundation
import Combine
import UIKit

struct LibrarySong: Identifiable, Equatable {
    let id: MPMediaEntityPersistentID
    let title: String
    let artist: String
    let assetURL: URL
    let dateAdded: Date
    let duration: TimeInterval

    var displayTitle: String {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Untitled Track"
        }
        return title
    }

    var displaySubtitle: String {
        if artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Unknown Artist"
        }
        return artist
    }
}

final class LibraryManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: MPMediaLibraryAuthorizationStatus
    @Published private(set) var songs: [LibrarySong] = []
    @Published private(set) var currentSong: LibrarySong?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var lastUpdated: Date?

    private let mediaLibrary = MPMediaLibrary.default()
    private let queuePlayer = AVQueuePlayer()
    private var libraryObservers: [NSObjectProtocol] = []
    private var timeControlObservation: NSKeyValueObservation?
    private let fetchQueue = DispatchQueue(label: "com.mixnotes.librarymanager.fetch", qos: .userInitiated)
    private var isObservingLibraryChanges = false

    override init() {
        authorizationStatus = MPMediaLibrary.authorizationStatus()
        super.init()
        observePlayer()
        registerForAppLifecycle()

        if authorizationStatus == .authorized {
            beginLibraryObservation()
            refreshLibrary()
        }
    }

    deinit {
        teardownObservers()
        queuePlayer.removeAllItems()
    }

    func requestAuthorization() {
        let currentStatus = MPMediaLibrary.authorizationStatus()
        authorizationStatus = currentStatus

        guard currentStatus == .notDetermined else {
            handlePostAuthorizationStatus(currentStatus)
            return
        }

        MPMediaLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                self?.handlePostAuthorizationStatus(status)
            }
        }
    }

    func refreshLibrary() {
        guard authorizationStatus == .authorized else {
            songs = []
            currentSong = nil
            return
        }

        isRefreshing = true

        fetchQueue.async { [weak self] in
            guard let self else { return }

            let query = MPMediaQuery.songs()
            let noCloudPredicate = MPMediaPropertyPredicate(
                value: false,
                forProperty: MPMediaItemPropertyIsCloudItem,
                comparisonType: .equalTo
            )
            query.addFilterPredicate(noCloudPredicate)

            let items = query.items ?? []
            let filtered = items.filter { item in
                guard let assetURL = item.assetURL else { return false }
                let isDRMFree = item.hasProtectedAsset == false
                let isOnDevice = item.isCloudItem == false
                return isDRMFree && isOnDevice && !assetURL.absoluteString.isEmpty
            }

            let sorted = filtered.sorted { lhs, rhs in
                let lhsDate = lhs.dateAdded ?? .distantPast
                let rhsDate = rhs.dateAdded ?? .distantPast
                if lhsDate == rhsDate {
                    return lhs.title ?? "" > rhs.title ?? ""
                }
                return lhsDate > rhsDate
            }

            let limited = Array(sorted.prefix(50))
            let librarySongs: [LibrarySong] = limited.compactMap { item in
                guard let assetURL = item.assetURL else { return nil }
                return LibrarySong(
                    id: item.persistentID,
                    title: item.title ?? "",
                    artist: item.artist ?? "",
                    assetURL: assetURL,
                    dateAdded: item.dateAdded ?? .distantPast,
                    duration: item.playbackDuration
                )
            }

            DispatchQueue.main.async {
                self.songs = librarySongs
                self.isRefreshing = false
                self.lastUpdated = Date()

                if let currentSong = self.currentSong, librarySongs.contains(currentSong) == false {
                    self.queuePlayer.pause()
                    self.queuePlayer.removeAllItems()
                    self.currentSong = nil
                }
            }
        }
    }

    func play(_ song: LibrarySong) {
        guard authorizationStatus == .authorized else { return }

        if currentSong?.id == song.id {
            togglePlayback()
            return
        }

        prepareAudioSessionIfNeeded()

        let playerItem = AVPlayerItem(url: song.assetURL)
        queuePlayer.removeAllItems()
        queuePlayer.insert(playerItem, after: nil)
        currentSong = song
        queuePlayer.play()
    }

    func pause() {
        queuePlayer.pause()
    }

    func resume() {
        guard queuePlayer.currentItem != nil else { return }
        prepareAudioSessionIfNeeded()
        queuePlayer.play()
    }

    func togglePlayback() {
        guard queuePlayer.currentItem != nil else { return }
        if queuePlayer.timeControlStatus == .paused {
            resume()
        } else {
            pause()
        }
    }

    private func handlePostAuthorizationStatus(_ status: MPMediaLibraryAuthorizationStatus) {
        switch status {
        case .authorized:
            beginLibraryObservation()
            refreshLibrary()
        default:
            songs = []
            currentSong = nil
        }
    }

    private func prepareAudioSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("LibraryManager audio session error: \(error)")
        }
    }

    private func observePlayer() {
        timeControlObservation = queuePlayer.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.isPlaying = player.timeControlStatus == .playing
            }
        }

        let completionObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let item = notification.object as? AVPlayerItem else { return }
            if item == self.queuePlayer.currentItem {
                self.queuePlayer.seek(to: .zero)
                self.queuePlayer.pause()
                self.isPlaying = false
            }
        }
        libraryObservers.append(completionObserver)
    }

    private func registerForAppLifecycle() {
        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshLibrary()
        }
        libraryObservers.append(foregroundObserver)
    }

    private func beginLibraryObservation() {
        guard isObservingLibraryChanges == false else { return }
        mediaLibrary.beginGeneratingLibraryChangeNotifications()

        let libraryChangeObserver = NotificationCenter.default.addObserver(
            forName: .MPMediaLibraryDidChange,
            object: mediaLibrary,
            queue: .main
        ) { [weak self] _ in
            self?.refreshLibrary()
        }
        libraryObservers.append(libraryChangeObserver)
        isObservingLibraryChanges = true
    }

    private func teardownObservers() {
        if isObservingLibraryChanges {
            mediaLibrary.endGeneratingLibraryChangeNotifications()
        }
        libraryObservers.forEach { NotificationCenter.default.removeObserver($0) }
        libraryObservers.removeAll()
        timeControlObservation?.invalidate()
        timeControlObservation = nil
    }
}
