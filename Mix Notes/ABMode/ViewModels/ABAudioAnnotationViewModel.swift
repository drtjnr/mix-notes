import Foundation
import AVFoundation
import MediaPlayer
import UIKit

final class ABAudioAnnotationViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    enum AudioSlot: String, CaseIterable {
        case a
        case b

        var displayLabel: String { rawValue }

        var isInvertedAppearance: Bool {
            self == .b
        }
    }

    struct AudioSource: Equatable {
        enum Kind {
            case stored(StoredAudioFile)
            case library(LibrarySong)
        }

        let kind: Kind

        var identifier: String {
            switch kind {
            case .stored(let file):
                return "stored-\(file.id)"
            case .library(let song):
                return "library-\(song.id)"
            }
        }

        var displayName: String {
            switch kind {
            case .stored(let file):
                return file.displayName
            case .library(let song):
                return song.displayTitle
            }
        }

        var duration: TimeInterval {
            switch kind {
            case .stored(let file):
                return file.duration
            case .library(let song):
                return song.duration
            }
        }

        var url: URL? {
            switch kind {
            case .stored(let file):
                return file.resolvedStoredFileURL
            case .library(let song):
                return song.assetURL
            }
        }

        var storedFile: StoredAudioFile? {
            if case .stored(let file) = kind { return file }
            return nil
        }

        var librarySong: LibrarySong? {
            if case .library(let song) = kind { return song }
            return nil
        }

        static func == (lhs: AudioSource, rhs: AudioSource) -> Bool {
            lhs.identifier == rhs.identifier
        }
    }

    // MARK: - Published State

    @Published private(set) var slotAssignments: [AudioSlot: AudioSource] = [:]
    @Published var storedAudioFiles: [StoredAudioFile] = []
    @Published var isLoadingFromBrowse = false
    @Published var isPlaying = false
    @Published var hasLoadedAudio = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var currentFileName: String = ""
    @Published var hideCurrentFileName = false
    @Published var activeSlot: AudioSlot?

    // MARK: - Private Properties

    private var slotPlayers: [AudioSlot: AVAudioPlayer] = [:]
    private var timer: Timer?
    private var nowPlayingInfo: [String: Any] = [:]

    // MARK: - Initialisation

    override init() {
        super.init()
        loadStoredFilesList()
        cleanUpInvalidStoredFiles()
    }

    deinit {
        stopTimer()
        slotPlayers.values.forEach { $0.stop() }
    }

    // MARK: - Public API

    func selectStoredFile(_ storedFile: StoredAudioFile) {
        if let slot = slot(for: storedFile) {
            removeSlot(slot)
            return
        }
        assignSource(.init(kind: .stored(storedFile)))
    }

    func selectLibrarySong(_ song: LibrarySong) {
        if let slot = slot(for: song) {
            removeSlot(slot)
            return
        }
        assignSource(.init(kind: .library(song)))
    }

    func slot(for storedFile: StoredAudioFile) -> AudioSlot? {
        slotAssignments.first { $0.value.storedFile?.id == storedFile.id }?.key
    }

    func slot(for song: LibrarySong) -> AudioSlot? {
        slotAssignments.first { $0.value.librarySong?.id == song.id }?.key
    }

    func toggleActiveSlot() {
        guard hasLoadedAudio, let currentSlot = activeSlot else { return }
        let nextSlot: AudioSlot = currentSlot == .a ? .b : .a
        guard slotAssignments[nextSlot] != nil else { return }

        if !isPlaying {
            let referenceTime = slotPlayers[currentSlot]?.currentTime ?? currentTime
            syncPlayers(to: referenceTime, restartPlayback: false)
        }

        setActiveSlot(nextSlot, animated: isPlaying)
    }

    func toggleFilenameVisibility() {
        hideCurrentFileName.toggle()
    }

    func togglePlayback() {
        isPlaying ? pauseAudio() : playAudio()
    }

    func playAudio() {
        guard hasLoadedAudio else { return }

        do {
            try configureAudioSession()
        } catch {
            print("Audio session error: \(error)")
        }

        guard !slotPlayers.isEmpty else { return }

        syncPlayers(to: currentTime, restartPlayback: true)
    }

    func pauseAudio() {
        slotPlayers.values.forEach { $0.pause() }
        isPlaying = false
        stopTimer()
        updateNowPlayingInfo(playbackRate: 0.0)
    }

    func goBackward(by seconds: TimeInterval) {
        guard hasLoadedAudio else { return }
        let newTime = max(0, currentTime - seconds)
        let wasPlaying = isPlaying
        syncPlayers(to: newTime, restartPlayback: wasPlaying)
    }

    func goForward(by seconds: TimeInterval) {
        guard hasLoadedAudio else { return }
        let newTime = min(duration, currentTime + seconds)
        let wasPlaying = isPlaying
        syncPlayers(to: newTime, restartPlayback: wasPlaying)
    }

    func goToBeginning() {
        guard hasLoadedAudio else { return }
        let wasPlaying = isPlaying
        syncPlayers(to: 0, restartPlayback: wasPlaying)
    }

    func seek(to progress: Double) {
        guard hasLoadedAudio, duration > 0 else { return }
        let newTime = duration * max(0, min(1, progress))
        let wasPlaying = isPlaying
        syncPlayers(to: newTime, restartPlayback: wasPlaying)
    }

    func reset() {
        slotPlayers.values.forEach { $0.stop() }
        slotPlayers.removeAll()
        slotAssignments.removeAll()
        activeSlot = nil
        hasLoadedAudio = false
        isPlaying = false
        currentTime = 0
        progress = 0
        duration = 0
        currentFileName = ""
        hideCurrentFileName = false
        stopTimer()
        clearNowPlayingInfo()
    }

    func deleteStoredFile(_ storedFile: StoredAudioFile) {
        storedAudioFiles.removeAll { $0.id == storedFile.id }
        saveStoredFilesList()

        if let slot = slot(for: storedFile) {
            removeSlot(slot)
        }
    }

    func syncStoredFiles(with files: [StoredAudioFile]) {
        storedAudioFiles = files
        removeMissingSlotAssignments()
    }

    func loadAudio(from url: URL) {
        isLoadingFromBrowse = true

        let shouldRequestSecurityScope = requiresSecurityScopedAccess(for: url)
        var didStartAccessing = false

        if shouldRequestSecurityScope {
            didStartAccessing = url.startAccessingSecurityScopedResource()
            if !didStartAccessing {
                print("Failed to access the selected file at \(url.path)")
                isLoadingFromBrowse = false
                return
            }
        }

        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
            isLoadingFromBrowse = false
        }

        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioDirectory = documentsDirectory.appendingPathComponent("AudioFiles")

            if !FileManager.default.fileExists(atPath: audioDirectory.path) {
                try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
            }

            let fileName = url.deletingPathExtension().lastPathComponent
            let fileExtension = url.pathExtension
            let uniqueFileName = "\(fileName)_\(UUID().uuidString).\(fileExtension)"
            let storedURL = audioDirectory.appendingPathComponent(uniqueFileName)

            try FileManager.default.copyItem(at: url, to: storedURL)

            let audioPlayer = try AVAudioPlayer(contentsOf: storedURL)
            let storedFile = StoredAudioFile(
                fileName: fileName,
                originalURL: url,
                storedURL: storedURL,
                duration: audioPlayer.duration
            )

            storedAudioFiles.append(storedFile)
            saveStoredFilesList()

            assignSource(.init(kind: .stored(storedFile)))
        } catch {
            print("Error loading audio: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func requiresSecurityScopedAccess(for url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let standardizedPath = url.standardizedFileURL.path

        let sandboxRoots: [String] = [
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first,
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
            URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
            Bundle.main.bundleURL
        ].compactMap { $0?.standardizedFileURL.path }

        return !sandboxRoots.contains { standardizedPath.hasPrefix($0) }
    }

    private func assignSource(_ source: AudioSource) {
        if let existingSlot = slot(for: source) {
            setActiveSlot(existingSlot)
            return
        }

        let wasPlaying = isPlaying
        let targetSlot: AudioSlot
        if slotAssignments[.a] == nil {
            targetSlot = .a
        } else if slotAssignments[.b] == nil {
            targetSlot = .b
        } else if let activeSlot {
            targetSlot = activeSlot
        } else {
            targetSlot = .a
        }

        slotAssignments[targetSlot] = source
        preparePlayer(for: targetSlot, with: source)

        if activeSlot == nil || activeSlot == targetSlot {
            setActiveSlot(targetSlot)
            if wasPlaying {
                syncPlayers(to: currentTime, restartPlayback: true)
            }
        } else {
            syncPlayers(to: currentTime, restartPlayback: wasPlaying)
        }

        hasLoadedAudio = AudioSlot.allCases.allSatisfy { slotAssignments[$0] != nil }
        if hasLoadedAudio {
            updateDurationFromActiveSlot()
        }
    }

    private func removeSlot(_ slot: AudioSlot) {
        slotPlayers[slot]?.stop()
        slotPlayers[slot] = nil
        slotAssignments.removeValue(forKey: slot)

        if activeSlot == slot {
            let otherSlot: AudioSlot = slot == .a ? .b : .a
            if slotAssignments[otherSlot] != nil {
                setActiveSlot(otherSlot, animated: true)
            } else {
                setActiveSlot(nil, allowFallbackToNil: true, animated: true)
            }
        } else {
            updateVolumesForActiveSlot(animated: true)
        }

        hasLoadedAudio = AudioSlot.allCases.allSatisfy { slotAssignments[$0] != nil }
        if !hasLoadedAudio {
            isPlaying = false
            stopTimer()
            updateNowPlayingInfo(playbackRate: 0.0)
        }
    }

    private func removeMissingSlotAssignments() {
        let validIDs = Set(storedAudioFiles.map(\.id))
        for (slot, source) in slotAssignments {
            if case .stored(let file) = source.kind, !validIDs.contains(file.id) {
                removeSlot(slot)
            }
        }
    }

    private func slot(for source: AudioSource) -> AudioSlot? {
        slotAssignments.first { $0.value == source }?.key
    }

    private func preparePlayer(for slot: AudioSlot, with source: AudioSource) {
        guard let url = source.url else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.numberOfLoops = 0
            player.currentTime = min(currentTime, player.duration)
            player.volume = slot == activeSlot ? 1.0 : 0.0
            slotPlayers[slot]?.stop()
            slotPlayers[slot] = player
        } catch {
            print("Error preparing audio player: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.removeSlot(slot)
            }
        }
    }

    private func syncPlayers(to time: TimeInterval, restartPlayback: Bool) {
        let clamped = max(0, min(time, duration > 0 ? duration : time))
        let players = Array(slotPlayers.values)

        guard !players.isEmpty else {
            applyCurrentTime(clamped)
            return
        }

        stopTimer()

        let startTime = (players.first?.deviceCurrentTime ?? 0) + 0.02

        for player in players {
            player.stop()
        }

        for player in players {
            let target = min(clamped, player.duration)
            player.currentTime = target
            player.prepareToPlay()
        }

        applyCurrentTime(clamped)

        if restartPlayback {
            for player in players {
                player.play(atTime: startTime)
            }
            updateVolumesForActiveSlot(animated: false)
            if !isPlaying {
                isPlaying = true
            }
            startTimer()
            updateNowPlayingInfo(playbackRate: 1.0)
        } else {
            stopTimer()
            if isPlaying {
                isPlaying = false
            }
            updateNowPlayingInfo(playbackRate: 0.0)
        }
    }

    private func applyCurrentTime(_ time: TimeInterval) {
        currentTime = time
        progress = duration > 0 ? time / duration : 0
        updateNowPlayingElapsedTime(time)
    }

    private func setActiveSlot(_ slot: AudioSlot?, allowFallbackToNil: Bool = false, animated: Bool = false) {
        guard let slot else {
            if allowFallbackToNil {
                activeSlot = nil
                updateDurationFromActiveSlot()
                currentFileName = ""
                updateVolumesForActiveSlot(animated: animated)
                clearNowPlayingInfo()
            }
            return
        }

        guard slotAssignments[slot] != nil else {
            if allowFallbackToNil {
                activeSlot = nil
                clearNowPlayingInfo()
                currentFileName = ""
                updateDurationFromActiveSlot()
                updateVolumesForActiveSlot(animated: animated)
            }
            return
        }

        activeSlot = slot
        updateDurationFromActiveSlot()
        currentFileName = slotAssignments[slot]?.displayName ?? ""
        updateVolumesForActiveSlot(animated: animated)
        updateNowPlayingInfo(playbackRate: isPlaying ? 1.0 : 0.0)
    }

    private func updateDurationFromActiveSlot() {
        guard let activeSlot, let source = slotAssignments[activeSlot] else {
            duration = 0
            return
        }

        let newDuration = max(0, source.duration)
        duration = newDuration
        currentTime = min(currentTime, newDuration)
        progress = newDuration > 0 ? currentTime / newDuration : 0
    }

    private func updateVolumesForActiveSlot(animated: Bool = false) {
        for (slot, player) in slotPlayers {
            let targetVolume: Float = slot == activeSlot ? 1.0 : 0.0
            if animated, isPlaying {
                player.setVolume(targetVolume, fadeDuration: 0.12)
            } else {
                player.volume = targetVolume
            }
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let activeSlot, let player = self.slotPlayers[activeSlot] else { return }
            let current = player.currentTime
            self.applyCurrentTime(current)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
        try audioSession.setActive(true)
    }

    private func updateNowPlayingInfo(playbackRate: Float) {
        guard let activeSlot, let source = slotAssignments[activeSlot] else {
            clearNowPlayingInfo()
            return
        }

        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = source.displayName
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate
        info[MPMediaItemPropertyPlaybackDuration] = duration

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        nowPlayingInfo = info
    }

    private func updateNowPlayingElapsedTime(_ time: TimeInterval) {
        guard !nowPlayingInfo.isEmpty else { return }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func clearNowPlayingInfo() {
        nowPlayingInfo = [:]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func loadStoredFilesList() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let storedFilesURL = documentsDirectory.appendingPathComponent("storedFiles.json")

        do {
            let data = try Data(contentsOf: storedFilesURL)
            let loadedFiles = try JSONDecoder().decode([StoredAudioFile].self, from: data)
            storedAudioFiles = loadedFiles
        } catch {
            storedAudioFiles = []
        }
    }

    private func saveStoredFilesList() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let storedFilesURL = documentsDirectory.appendingPathComponent("storedFiles.json")

        do {
            let data = try JSONEncoder().encode(storedAudioFiles)
            try data.write(to: storedFilesURL)
        } catch {
            print("Error saving stored files list: \(error)")
        }
    }

    private func cleanUpInvalidStoredFiles() {
        let validFiles = storedAudioFiles.filter { storedFile in
            FileManager.default.fileExists(atPath: storedFile.resolvedStoredFileURL.path)
        }

        if validFiles.count != storedAudioFiles.count {
            storedAudioFiles = validFiles
            saveStoredFilesList()
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard let slot = slotPlayers.first(where: { $0.value === player })?.key else { return }
        if slot == activeSlot {
            DispatchQueue.main.async {
                self.isPlaying = false
                self.stopTimer()
                self.applyCurrentTime(self.duration)
                self.updateNowPlayingInfo(playbackRate: 0.0)
            }
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(String(describing: error))")
    }
}

// MARK: - Preview Support

extension ABAudioAnnotationViewModel {
    static var preview: ABAudioAnnotationViewModel {
        let viewModel = ABAudioAnnotationViewModel()

        // Fake stored files for previews
        let fileA = StoredAudioFile(
            fileName: "Track A",
            originalURL: URL(fileURLWithPath: "/tmp/a.mp3"),
            storedURL: URL(fileURLWithPath: "/tmp/a.mp3"),
            duration: 240
        )

        let fileB = StoredAudioFile(
            fileName: "Track B",
            originalURL: URL(fileURLWithPath: "/tmp/b.mp3"),
            storedURL: URL(fileURLWithPath: "/tmp/b.mp3"),
            duration: 240
        )

        viewModel.storedAudioFiles = [fileA, fileB]
        viewModel.slotAssignments = [
            .a: AudioSource(kind: .stored(fileA)),
            .b: AudioSource(kind: .stored(fileB))
        ]
        viewModel.currentFileName = fileA.displayName
        viewModel.duration = fileA.duration
        viewModel.hasLoadedAudio = true
        viewModel.activeSlot = .a

        return viewModel
    }
}
