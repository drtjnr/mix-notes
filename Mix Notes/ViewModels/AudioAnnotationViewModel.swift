import Foundation
import AVFoundation
import UniformTypeIdentifiers

class AudioAnnotationViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var annotations: [AudioAnnotation] = []
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var hasLoadedAudio: Bool = false
    @Published var customAnnotationText: String = ""
    @Published var currentFileName: String = ""
    @Published var progress: Double = 0
    @Published var duration: TimeInterval = 0
    @Published var storedAudioFiles: [StoredAudioFile] = []
    @Published var showingRecents: Bool = false
    @Published var isLoadingFromBrowse: Bool = false
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var currentFileURL: URL?
    private var currentStoredFile: StoredAudioFile?
    
    override     init() {
        super.init()
        loadStoredFilesList()
        cleanUpInvalidStoredFiles()
    }
    
    func loadAudio(from url: URL) {
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access the selected file")
            return
        }
        
        do {
            // Configure audio session for playback with background capability
            try configureAudioSession()
            
            // Create a permanent copy in the app's documents directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioDirectory = documentsDirectory.appendingPathComponent("AudioFiles")
            
            // Create AudioFiles directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: audioDirectory.path) {
                try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
            }
            
            // Generate unique filename to avoid conflicts
            let fileName = url.deletingPathExtension().lastPathComponent
            let fileExtension = url.pathExtension
            let uniqueFileName = "\(fileName)_\(UUID().uuidString).\(fileExtension)"
            let storedURL = audioDirectory.appendingPathComponent(uniqueFileName)
            
            // Copy file to permanent storage
            try FileManager.default.copyItem(at: url, to: storedURL)
            
            // Create StoredAudioFile record
            let audioPlayer = try AVAudioPlayer(contentsOf: storedURL)
            let storedFile = StoredAudioFile(
                fileName: fileName,
                originalURL: url,
                storedURL: storedURL,
                duration: audioPlayer.duration
            )
            
            // Add to stored files list if not already present
            if !storedAudioFiles.contains(where: { $0.originalURL == url.absoluteString }) {
                storedAudioFiles.append(storedFile)
                saveStoredFilesList()
            }
            
            // Load the audio
            loadStoredAudio(storedFile)
            
        } catch {
            print("Error loading audio: \(error)")
            hasLoadedAudio = false
        }
        
        url.stopAccessingSecurityScopedResource()
    }
    
    func loadStoredAudio(_ storedFile: StoredAudioFile) {
        print("Loading stored audio file: \(storedFile.fileName)")
        print("Stored URL: \(storedFile.storedURL)")
        
        do {
            // Stop any current playback first
            audioPlayer?.stop()
            audioPlayer = nil
            
            // Configure audio session for playback with background capability
            try configureAudioSession()
            
            let storedURL = URL(string: storedFile.storedURL)!
            print("Created URL from string: \(storedURL)")
            
            // Check if file exists
            let fileExists = FileManager.default.fileExists(atPath: storedURL.path)
            print("File exists at path: \(fileExists)")
            
            if !fileExists {
                print("File does not exist, removing from stored files list")
                // Remove the invalid file from stored files list
                storedAudioFiles.removeAll { $0.id == storedFile.id }
                saveStoredFilesList()
                hasLoadedAudio = false
                return
            }
            
            audioPlayer = try AVAudioPlayer(contentsOf: storedURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            currentFileURL = storedURL
            currentFileName = storedFile.fileName
            currentStoredFile = storedFile
            hasLoadedAudio = true
            duration = storedFile.duration
            
            print("Successfully loaded audio file. Duration: \(duration)")
            
            // Load any saved annotations for this file
            loadAnnotations(for: storedURL)
            
        } catch {
            print("Error loading stored audio: \(error)")
            hasLoadedAudio = false
        }
    }
    
    func togglePlayback() {
        if isPlaying {
            pauseAudio()
        } else {
            playAudio()
        }
    }
    
    func playAudio() {
        do {
            // Ensure audio session is active for playback
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer?.play()
            isPlaying = true
            startTimer()
        } catch {
            print("Error activating audio session: \(error)")
        }
    }
    
    func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func addAnnotation(_ type: AnnotationType, customText: String? = nil) {
        guard let currentTime = audioPlayer?.currentTime else { return }
        let adjustedTime = max(currentTime - 0.2, 0)
        let annotation = AudioAnnotation(
            timestamp: adjustedTime, 
            type: type,
            customText: customText
        )
        annotations.append(annotation)
        saveAnnotations() // Save after adding
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer, player.duration > 0 else { return }
            self.currentTime = player.currentTime
            self.progress = player.currentTime / player.duration
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Check if we need to change the category
            let currentCategory = audioSession.category
            let currentMode = audioSession.mode
            let currentOptions = audioSession.categoryOptions
            
            let needsCategoryChange = currentCategory != .playback || 
                                    currentMode != .default || 
                                    !currentOptions.contains(.allowAirPlay) || 
                                    !currentOptions.contains(.allowBluetoothHFP)
            
            if needsCategoryChange {
                // Deactivate the session first to avoid conflicts
                try audioSession.setActive(false)
                
                // Set the category and options
                try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothHFP])
            }
            
            // Activate the session if it's not already active
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true)
            }
        } catch {
            print("Audio session configuration failed: \(error)")
            // Try a simpler configuration as fallback
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
        }
    }
    
    func exportAnnotations() -> String {
        var lines: [String] = []
        
        // Add filename as header
        lines.append("File: \(currentFileName)")
        lines.append("") // Add blank line after header
        
        // Add annotations
        lines.append(contentsOf: annotations.sorted(by: { $0.timestamp < $1.timestamp }).map { annotation in
            // Format time as MM:SS.T (T = tenths of a second)
            let minutes = Int(annotation.timestamp) / 60
            let seconds = Int(annotation.timestamp) % 60
            let tenths = Int((annotation.timestamp.truncatingRemainder(dividingBy: 1)) * 10)
            let timeString = String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
            
            if annotation.type == .custom, let customText = annotation.customText {
                return "\(timeString): Custom - \(customText)"
            }
            return "\(timeString): \(annotation.type.rawValue)"
        })
        
        return lines.joined(separator: "\n")
    }
    
    func deleteAnnotation(_ annotation: AudioAnnotation) {
        annotations.removeAll { $0.id == annotation.id }
        saveAnnotations() // Save after deleting
    }
    
    func goBackward(by seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        let newTime = max(0, player.currentTime - seconds)
        player.currentTime = newTime
        currentTime = newTime
        progress = player.duration > 0 ? newTime / player.duration : 0
    }
    
    func goForward(by seconds: TimeInterval) {
        guard let player = audioPlayer, player.duration > 0 else { return }
        let newTime = min(player.duration, player.currentTime + seconds)
        player.currentTime = newTime
        currentTime = newTime
        progress = newTime / player.duration
    }
    
    func goToBeginning() {
        guard let player = audioPlayer else { return }
        player.currentTime = 0
        currentTime = 0
        progress = 0
    }
    
    func stop() {
        audioPlayer?.stop()
        isPlaying = false
        // Resetting current time to 0, which is typical for a stop button.
        audioPlayer?.currentTime = 0
        // We need to update the published properties as well
        currentTime = 0
        progress = 0
        stopTimer()
    }
    
    func rewindFiveSeconds() {
        guard let player = audioPlayer else { return }
        // Calculate new time and ensure it doesn't go below 0
        let newTime = max(player.currentTime - 5.0, 0)
        player.currentTime = newTime
    }
    
    func reset() {
        audioPlayer?.stop()
        audioPlayer = nil
        hasLoadedAudio = false
        isPlaying = false
        currentTime = 0
        currentFileName = ""
        duration = 0
        currentFileURL = nil
        currentStoredFile = nil
        stopTimer()
    }
    
    func deleteStoredFile(_ storedFile: StoredAudioFile) {
        // Remove from stored files list
        storedAudioFiles.removeAll { $0.id == storedFile.id }
        saveStoredFilesList()
        
        // Delete the actual file
        if let storedURL = URL(string: storedFile.storedURL) {
            try? FileManager.default.removeItem(at: storedURL)
        }
        
        // If this was the currently loaded file, reset
        if currentStoredFile?.id == storedFile.id {
            reset()
        }
    }
    
    func loadStoredFilesList() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let storedFilesURL = documentsDirectory.appendingPathComponent("storedFiles.json")
        
        do {
            let data = try Data(contentsOf: storedFilesURL)
            let loadedFiles = try JSONDecoder().decode([StoredAudioFile].self, from: data)
            storedAudioFiles = loadedFiles
        } catch {
            print("Error loading stored files list: \(error)")
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
            if let storedURL = URL(string: storedFile.storedURL) {
                let exists = FileManager.default.fileExists(atPath: storedURL.path)
                if !exists {
                    print("Removing invalid stored file: \(storedFile.fileName) at \(storedURL.path)")
                }
                return exists
            }
            print("Removing stored file with invalid URL: \(storedFile.fileName)")
            return false
        }
        
        if validFiles.count != storedAudioFiles.count {
            print("Cleaning up \(storedAudioFiles.count - validFiles.count) invalid stored files")
            storedAudioFiles = validFiles
            saveStoredFilesList()
        }
        
        // If more than 50% of files are invalid, clear the entire list
        if storedAudioFiles.count > 0 && validFiles.count < storedAudioFiles.count / 2 {
            print("Too many invalid files, clearing entire stored files list")
            storedAudioFiles = []
            saveStoredFilesList()
        }
    }
    
    
    
    func seek(to progress: Double) {
        guard let player = audioPlayer else { return }
        let time = progress * player.duration
        player.currentTime = time
        currentTime = time
        
        // If we were playing before the seek, continue playing
        if isPlaying {
            player.play()
        }
    }
    
    private func getAnnotationsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Annotations")
    }
    
    private func getAnnotationsFileURL(for audioFileURL: URL) -> URL {
        // Create a unique identifier based on the audio file path
        let audioFileIdentifier = audioFileURL.lastPathComponent
        return getAnnotationsDirectory()
            .appendingPathComponent(audioFileIdentifier)
            .appendingPathExtension("annotations")
    }
    
    private func saveAnnotations() {
        guard let fileURL = currentFileURL else { return }
        
        do {
            let annotationsDirectory = getAnnotationsDirectory()
            if !FileManager.default.fileExists(atPath: annotationsDirectory.path) {
                try FileManager.default.createDirectory(at: annotationsDirectory, withIntermediateDirectories: true)
            }
            
            let data = try JSONEncoder().encode(annotations)
            try data.write(to: getAnnotationsFileURL(for: fileURL))
        } catch {
            print("Error saving annotations: \(error)")
        }
    }
    
    private func loadAnnotations(for fileURL: URL) {
        do {
            let data = try Data(contentsOf: getAnnotationsFileURL(for: fileURL))
            let loadedAnnotations = try JSONDecoder().decode([AudioAnnotation].self, from: data)
            DispatchQueue.main.async {
                self.annotations = loadedAnnotations
            }
        } catch {
            print("Error loading annotations: \(error)")
            // If there's an error loading (like first time with this file), start with empty annotations
            DispatchQueue.main.async {
                self.annotations = []
            }
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.stopTimer()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player decode error: \(error?.localizedDescription ?? "Unknown error")")
        DispatchQueue.main.async {
            self.isPlaying = false
            self.stopTimer()
        }
    }
}

extension AudioAnnotationViewModel {
    static var preview: AudioAnnotationViewModel {
        let viewModel = AudioAnnotationViewModel()
        
        print("Attempting to load preview audio file...")
        
        print("Using placeholder audio data for preview.")
        viewModel.hasLoadedAudio = true
        viewModel.currentFileName = "Preview Audio"
        viewModel.duration = 60.0
        
        // Add sample annotations regardless of audio loading
        viewModel.annotations = [
            AudioAnnotation(timestamp: 1.2, type: .tooLoud),
            AudioAnnotation(timestamp: 3.5, type: .tuning),
            AudioAnnotation(timestamp: 5.8, type: .glitch),
            AudioAnnotation(timestamp: 8.2, type: .custom, customText: "Test note")
        ]
        
        return viewModel
    }
} 
