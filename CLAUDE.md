# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mix Notes is an iOS/iPadOS audio annotation application built with SwiftUI. It allows users to annotate audio files during playback with timestamps and custom notes. The app supports three modes:
- **Mix Mode**: Standard annotation recording for audio files
- **AB Mode**: A/B comparison of two tracks with synchronized playback
- **Chords Mode**: Chord chart creation with Nashville notation support

## Build and Test Commands

### Building the Project
```bash
xcodebuild -project "Mix Notes.xcodeproj" -scheme "Mix Notes" -configuration Debug build
```

### Running Tests
```bash
# Run all tests
xcodebuild test -project "Mix Notes.xcodeproj" -scheme "Mix Notes" -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run specific test target
xcodebuild test -project "Mix Notes.xcodeproj" -scheme "Mix Notes" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:Mix_NotesTests

# Run UI tests only
xcodebuild test -project "Mix Notes.xcodeproj" -scheme "Mix Notes" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:Mix_NotesUITests
```

### Opening in Xcode
```bash
open "Mix Notes.xcodeproj"
```

## Architecture

### Design Pattern
The app follows **MVVM (Model-View-ViewModel)** architecture with SwiftUI:
- **Models**: Pure data structures (`AudioAnnotation`, `StoredAudioFile`)
- **ViewModels**: Observable business logic with `@Published` properties (`AudioAnnotationViewModel`, `ABAudioAnnotationViewModel`)
- **Views**: SwiftUI declarative UI
- **Managers**: Specialized service classes (`LibraryManager` for Apple Music integration)

### Key Architectural Patterns
- **Observer Pattern**: Extensive use of Combine framework with `@Published` properties
- **Strategy Pattern**: Different audio source types (stored files vs library songs) with unified interface
- **State Machine**: App modes (Mix, AB, Chords) with conditional UI rendering in ContentView

### Source Structure
```
Mix Notes/
├── Mix_NotesApp.swift          # App entry point
├── ContentView.swift           # Main UI container (1875 lines - handles all 3 modes)
├── Models/
│   ├── AudioAnnotation.swift   # Annotation data model
│   └── StoredAudioFile.swift   # Imported file metadata
├── ViewModels/
│   └── AudioAnnotationViewModel.swift  # Mix mode business logic
├── ABMode/
│   ├── ViewModels/ABAudioAnnotationViewModel.swift  # AB mode logic
│   └── Views/                  # AB mode UI components
├── Managers/
│   └── LibraryManager.swift    # Apple Music library integration
├── Views/
│   ├── MusicLibrarySection.swift
│   ├── BannerAdView.swift      # Google AdMob integration
│   └── ShareSheet.swift
└── Rendering/
    └── WaveformRenderer.swift  # Metal-based waveform visualization
```

## Data Persistence

The app uses JSON-based file persistence in the Documents directory:

- **Stored Files List**: `Documents/storedFiles.json` - List of imported audio files
- **Annotations**: `Documents/Annotations/{identifier}.annotations` - Per-file annotation data
- **Chord Overrides**: `Documents/Annotations/{identifier}-chords.json` - Custom chord labels for chords mode
- **Audio Files**: `Documents/AudioFiles/{unique-filename}` - Actual imported audio files

All file references use relative paths for portability across app updates.

## Audio Playback System

### Audio Sources
1. **Stored Files**: Imported audio files using `AVAudioPlayer`
2. **Library Songs**: Apple Music library tracks using `AVQueuePlayer` with `AVPlayerItem`

### Key Features
- Background audio playback (configured in `UIBackgroundModes`)
- Lock screen controls via `MPNowPlayingInfoCenter`
- Remote command handling via `MPRemoteCommandCenter`
- AirPlay and Bluetooth support via `AVAudioSession`

### AB Mode Specifics
- Maintains two separate `AVAudioPlayer` instances (Slot A & B)
- Synchronized playback with independent volume control
- Seamless switching between tracks at the same timestamp

## Apple Music Integration

The `LibraryManager` handles Apple Music library access:
1. Requests `MPMediaLibrary` authorization
2. Queries for songs using `MPMediaQuery`
3. Filters for **DRM-free, on-device songs only** (limit: 50 songs)
4. Songs are published to `@Published songs` array for UI binding

**Note**: Cannot play DRM-protected Apple Music subscription content.

## Google AdMob Integration

- **Package**: `swift-package-manager-google-mobile-ads` v11.8.0+
- **Implementation**: `BannerAdView` wraps `GADBannerView` using `UIViewRepresentable`
- **Initialization**: `AppDelegate` initializes GAD SDK on launch
- **Configuration**: Ad Unit ID in `Mix-Notes-Info.plist`

## Development Notes

### iOS Version Requirement
**Deployment Target: iOS 18.2** - This is an extremely recent requirement. Be aware that this limits the user base significantly. Consider if newer APIs are truly necessary.

### ContentView Complexity
`ContentView.swift` is 1875 lines and handles all three app modes. When making changes:
- Understand which mode you're modifying (Mix, AB, or Chords)
- Consider extracting reusable view components to separate files
- Test all three modes after UI changes

### Preview Support
ViewModels include `.preview` static properties with mock data for SwiftUI previews. Always maintain these when modifying ViewModels.

### Testing Coverage
Test coverage is currently minimal. When adding new features, expand test coverage accordingly.

## Common File Operations

### Adding Annotations
Annotations are stored per audio file/song using a unique identifier:
- Stored files: Use file URL as identifier
- Library songs: Use `MPMediaEntityPersistentID` as identifier

The ViewModel's `addAnnotation()` method:
1. Creates `AudioAnnotation` with current playback timestamp
2. Appends to `@Published annotations` array
3. Saves to `Documents/Annotations/{identifier}.annotations` as JSON

### Importing Audio Files
1. User selects file via document picker
2. File is copied to `Documents/AudioFiles/` with unique name
3. `StoredAudioFile` metadata created with relative path
4. Added to `storedFiles.json` for persistence

## Key Permissions

Declared in `Mix-Notes-Info.plist`:
- `NSAppleMusicUsageDescription`: Required for library access
- Background audio: `UIBackgroundModes` includes `audio`

## Custom Branding

- **Font**: League Spartan Bold (`leaguespartan-bold.ttf`)
- **Color Scheme**: Cream, warm whites, charcoal, taupe variants (see `MixNotesDesign`)
- **Bundle ID**: `com.davethomasjunior.MixNotes`
