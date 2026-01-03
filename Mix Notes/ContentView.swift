//
//  ContentView.swift
//  Mix Notes
//
//  Created by David Thomas on 1/4/25.
//

import SwiftUI
import UniformTypeIdentifiers
import GoogleMobileAds
import UIKit
import MediaPlayer

// MARK: - Design System

enum MixNotesDesign {
    // Warm cream color palette
    static let cream = Color(red: 0.98, green: 0.97, blue: 0.96)
    static let warmWhite = Color(red: 0.995, green: 0.99, blue: 0.985)
    static let charcoal = Color(red: 0.17, green: 0.17, blue: 0.16)
    static let warmGray = Color(red: 0.55, green: 0.53, blue: 0.50)
    static let lightTaupe = Color(red: 0.88, green: 0.86, blue: 0.83)
    static let mediumTaupe = Color(red: 0.75, green: 0.72, blue: 0.68)
    static let darkTaupe = Color(red: 0.35, green: 0.33, blue: 0.30)

    // SF Pro font
    static func sfFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // SF Pro italic for emphasis
    static func sfItalic(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default).italic()
    }
}

struct MixNotesTitleView: View {
    var body: some View {
        Text("mix notes")
            .font(.custom("LeagueSpartan-Bold", size: 20))
            .foregroundColor(MixNotesDesign.charcoal)
            .kerning(-0.3)
    }
}

struct ABTitleView: View {
    var body: some View {
        Text("ab")
            .font(.custom("LeagueSpartan-Bold", size: 20))
            .foregroundColor(MixNotesDesign.charcoal)
            .kerning(-0.3)
    }
}

struct ChordsTitleView: View {
    var body: some View {
        Text("chords")
            .font(.custom("LeagueSpartan-Bold", size: 20))
            .foregroundColor(MixNotesDesign.charcoal)
            .kerning(-0.3)
    }
}

struct ABModeToggleButton: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isOn.toggle()
            }
        } label: {
            Text("ab")
                .font(.custom("LeagueSpartan-Bold", size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isOn ? MixNotesDesign.charcoal : MixNotesDesign.cream)
                .foregroundColor(isOn ? MixNotesDesign.cream : MixNotesDesign.charcoal)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ChordsModeToggleButton: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isOn.toggle()
            }
        } label: {
            Text("chords")
                .font(.custom("LeagueSpartan-Bold", size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isOn ? MixNotesDesign.charcoal : MixNotesDesign.cream)
                .foregroundColor(isOn ? MixNotesDesign.cream : MixNotesDesign.charcoal)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ContentView: View {
    @StateObject private var viewModel: AudioAnnotationViewModel
    @StateObject private var abViewModel = ABAudioAnnotationViewModel()
    @StateObject private var chordsViewModel = AudioAnnotationViewModel(annotationNamespace: "chords")
    @StateObject private var libraryManager = LibraryManager()
    @ObservedObject private var repeatStateManager = RepeatStateManager.shared
    @State private var showingShareSheet = false
    @State private var showingChordsShareSheet = false
    @State private var showingCustomAnnotation = false
    @State private var customAnnotationText = ""
    @State private var pendingCustomTimestamp: TimeInterval?
    @State private var showingInstrumentPicker = false
    @State private var selectedAnnotationType: AnnotationType?
    @State private var mode: AppMode = .mix
    @State private var selectedKeyIndex: Double = 0
    @State private var isMinorKey = false
    @State private var chordOverrides: [Int: AudioAnnotationViewModel.ChordOverride] = [:]
    @State private var editingChordIndex: Int?
    @State private var editingChordText = ""
    @State private var isDoublePlacement = false
    @State private var isEditMode = false
    @State private var isNashvilleMode = false
    @State private var nextPlacementBar = 0
    @State private var nextPlacementBeat = 0
    @State private var lastPlacedBar: Int?
    @State private var lastPlacedBeat: Int?

    let instrumentTypes = ["Vocals", "Bass", "Guitar / Keys", "Drums"]
    let columns = Array(repeating: GridItem(.flexible()), count: 3)
    private let abSelectionAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7)
    private let chordColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    private let keyNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
    private let beatsPerBar = 2
    private let barsPerLine = 4

    private enum AppMode {
        case mix
        case ab
        case chords
    }

    private enum ChordQuality {
        case major
        case minor
        case diminished
        case dominant7
        case major7
        case minor7
        case add9

        var suffix: String {
            switch self {
            case .major:
                return ""
            case .minor:
                return "m"
            case .diminished:
                return "dim"
            case .dominant7:
                return "7"
            case .major7:
                return "maj7"
            case .minor7:
                return "m7"
            case .add9:
                return "add9"
            }
        }
    }

    private enum KeyLabelMode {
        case notes
        case nashville
    }

    private struct ChordFormula {
        let offset: Int
        let quality: ChordQuality
    }

    private struct BarBeatSlot: Hashable {
        let bar: Int
        let beat: Int
    }

    private let majorChordsRow1 = [
        ChordFormula(offset: 0, quality: .major),
        ChordFormula(offset: 2, quality: .minor),
        ChordFormula(offset: 4, quality: .minor),
        ChordFormula(offset: 5, quality: .major),
        ChordFormula(offset: 7, quality: .major),
        ChordFormula(offset: 9, quality: .minor)
    ]
    private let majorChordsRow2 = [
        ChordFormula(offset: 0, quality: .major7),
        ChordFormula(offset: 2, quality: .minor7),
        ChordFormula(offset: 4, quality: .minor7),
        ChordFormula(offset: 5, quality: .major7),
        ChordFormula(offset: 7, quality: .dominant7),
        ChordFormula(offset: 9, quality: .minor7)
    ]
    private let minorChordsRow1 = [
        ChordFormula(offset: 0, quality: .minor),
        ChordFormula(offset: 3, quality: .major),
        ChordFormula(offset: 5, quality: .minor),
        ChordFormula(offset: 7, quality: .minor),
        ChordFormula(offset: 8, quality: .major),
        ChordFormula(offset: 10, quality: .major)
    ]
    private let minorChordsRow2 = [
        ChordFormula(offset: 0, quality: .minor7),
        ChordFormula(offset: 3, quality: .major7),
        ChordFormula(offset: 5, quality: .minor7),
        ChordFormula(offset: 7, quality: .minor7),
        ChordFormula(offset: 8, quality: .major7),
        ChordFormula(offset: 10, quality: .dominant7)
    ]

    private enum AdMobIdentifiers {
        static let bannerAdUnitID = "ca-app-pub-2186858726503482/7521622823"
    }

    init(viewModel: AudioAnnotationViewModel = AudioAnnotationViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var isShowingABPlayback: Bool {
        mode == .ab && abViewModel.hasLoadedAudio
    }

    private var isShowingMixPlayback: Bool {
        mode == .mix && viewModel.hasLoadedAudio
    }

    private var isShowingChordsPlayback: Bool {
        mode == .chords && chordsViewModel.hasLoadedAudio
    }

    private var isShowingList: Bool {
        !isShowingABPlayback && !isShowingMixPlayback && !isShowingChordsPlayback && !currentLoadingState
    }

    private var currentLoadingState: Bool {
        switch mode {
        case .ab:
            return abViewModel.isLoadingFromBrowse
        case .chords:
            return chordsViewModel.isLoadingFromBrowse
        case .mix:
            return viewModel.isLoadingFromBrowse
        }
    }

    private var chordFormulas: [ChordFormula] {
        if isNashvilleMode {
            return majorChordsRow1 + majorChordsRow2
        }
        if isMinorKey {
            return minorChordsRow1 + minorChordsRow2
        }
        return majorChordsRow1 + majorChordsRow2
    }

    private var chordChartBars: Int {
        let maxBar = chordsViewModel.annotations.compactMap { $0.barIndex }.max() ?? -1
        let baseBars = maxBar + 1
        let roundedBars = Int(ceil(Double(max(baseBars, 1)) / Double(barsPerLine))) * barsPerLine
        return max(4, roundedBars)
    }

    private var currentKeyName: String {
        let index = min(max(Int(selectedKeyIndex), 0), keyNames.count - 1)
        return keyNames[index]
    }

    private var currentKeyIndex: Int {
        min(max(Int(selectedKeyIndex), 0), keyNames.count - 1)
    }

    private var keyLabelMode: KeyLabelMode {
        isNashvilleMode ? .nashville : .notes
    }

    private var currentKeyDisplayName: String {
        if isNashvilleMode {
            return "Nashville"
        }
        return "\(currentKeyName) \(isMinorKey ? "minor" : "major")"
    }

    var body: some View {
        NavigationView {
            contentStack
        }
        .onAppear {
            libraryManager.requestAuthorization()
        }
        .onReceive(viewModel.$storedAudioFiles) { files in
            abViewModel.syncStoredFiles(with: files)
        }
        .onChange(of: mode) { _, newValue in
            if newValue != .ab {
                abViewModel.reset()
            }
            if newValue != .chords {
                chordsViewModel.reset()
            }
        }
        .onChange(of: chordsViewModel.currentAnnotationIdentifier) { _, _ in
            chordOverrides = chordsViewModel.loadChordOverrides(currentKeyIndex: currentKeyIndex)
            normalizeChordAnnotationsForChart()
            updateChordAnnotationsForKeyChange()
            let slot = nextAvailableSlot(fromBar: 0, fromBeat: 0, allowHalf: isDoublePlacement)
            nextPlacementBar = slot.bar
            nextPlacementBeat = slot.beat
        }
        .onChange(of: selectedKeyIndex) { _, _ in
            updateChordAnnotationsForKeyChange()
        }
        .onChange(of: isMinorKey) { _, _ in
            updateChordAnnotationsForKeyChange()
        }
        .onChange(of: isNashvilleMode) { _, _ in
            updateChordAnnotationsForKeyChange()
        }
        .onChange(of: isDoublePlacement) { _, newValue in
            if newValue, let lastBar = lastPlacedBar, lastPlacedBeat == 0 {
                let halfSlot = nextAvailableSlot(fromBar: lastBar, fromBeat: 1, allowHalf: true)
                if halfSlot.bar == lastBar, halfSlot.beat == 1 {
                    nextPlacementBar = halfSlot.bar
                    nextPlacementBeat = halfSlot.beat
                }
            } else if !newValue, nextPlacementBeat == 1 {
                let slot = nextAvailableSlot(fromBar: nextPlacementBar + 1, fromBeat: 0, allowHalf: false)
                nextPlacementBar = slot.bar
                nextPlacementBeat = slot.beat
            }
        }
    }

    private var contentStack: some View {
        VStack(spacing: 0) {
            mainContent

            if shouldShowBanner {
                Rectangle()
                    .fill(MixNotesDesign.lightTaupe)
                    .frame(height: 1)

                BannerAdView(adUnitID: AdMobIdentifiers.bannerAdUnitID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .padding(.vertical, 4)
            }
        }
        .background(MixNotesDesign.cream)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { principalToolbarItem }
        .toolbar { trailingToolbarItem }
        .toolbar { leadingToolbarItem }
        .toolbarBackground(MixNotesDesign.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [viewModel.exportAnnotations()])
        }
        .sheet(isPresented: $showingChordsShareSheet) {
            ShareSheet(activityItems: [exportChordChart()])
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if isShowingABPlayback {
            ABTitleView()
        } else if isShowingChordsPlayback {
            ChordsTitleView()
        } else {
            MixNotesTitleView()
        }
    }

    private var modeToggleButtons: some View {
        HStack(spacing: 8) {
            ABModeToggleButton(isOn: Binding(
                get: { mode == .ab },
                set: { mode = $0 ? .ab : .mix }
            ))
            ChordsModeToggleButton(isOn: Binding(
                get: { mode == .chords },
                set: { mode = $0 ? .chords : .mix }
            ))
        }
    }

    private var principalToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            titleView
        }
    }

    private var trailingToolbarItem: some ToolbarContent {
        let shouldShowExport = isShowingMixPlayback
        let shouldShowShare = isShowingChordsPlayback
        let shouldShowModeToggle = isShowingList

        return ToolbarItem(placement: .navigationBarTrailing) {
            if shouldShowExport {
                Button {
                    showingShareSheet = true
                } label: {
                    Text("Export")
                        .font(MixNotesDesign.sfFont(16))
                        .foregroundColor(MixNotesDesign.charcoal)
                }
            } else if shouldShowShare {
                Button {
                    showingChordsShareSheet = true
                } label: {
                    Text("Share")
                        .font(MixNotesDesign.sfFont(16))
                        .foregroundColor(MixNotesDesign.charcoal)
                }
            } else if shouldShowModeToggle {
                modeToggleButtons
            }
        }
    }

    private var leadingToolbarItem: some ToolbarContent {
        let shouldShowRecents = isShowingMixPlayback || isShowingABPlayback || isShowingChordsPlayback
        return ToolbarItem(placement: .navigationBarLeading) {
            if shouldShowRecents {
                Button {
                    handleRecentsTapped()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward")
                        Text("Recents")
                            .font(MixNotesDesign.sfFont(16))
                    }
                    .foregroundColor(MixNotesDesign.charcoal)
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if currentLoadingState {
            loadingView
        } else if isShowingABPlayback {
            ABPlaybackView(
                viewModel: abViewModel,
                adUnitID: AdMobIdentifiers.bannerAdUnitID
            )
        } else if isShowingMixPlayback {
            mixPlaybackView
        } else if isShowingChordsPlayback {
            chordsPlaybackView
        } else {
            audioListView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(MixNotesDesign.charcoal)

            Text("Loading audio file...")
                .font(MixNotesDesign.sfFont(18, weight: .medium))
                .foregroundColor(MixNotesDesign.charcoal)

            Text("Please wait while we prepare your audio file for playback")
                .font(MixNotesDesign.sfItalic(14))
                .foregroundColor(MixNotesDesign.warmGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MixNotesDesign.cream)
    }

    private var mixPlaybackView: some View {
        VStack(spacing: 16) {
            Text(viewModel.currentFileName)
                .font(MixNotesDesign.sfFont(17, weight: .medium))
                .foregroundColor(MixNotesDesign.charcoal)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            GeometryReader { geometry in
                HStack(spacing: 34) {
                    Button(action: { viewModel.goToBeginning() }) {
                        Image(systemName: "backward.end.fill")
                    }

                    Button(action: { viewModel.goBackward(by: 3) }) {
                        ZStack {
                            Image(systemName: "gobackward")
                            Text("3")
                                .font(.system(size: 10, weight: .bold))
                                .offset(x: 0.3, y: 1)
                        }
                    }

                    Button(action: { viewModel.togglePlayback() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .padding(8)
                            .background(
                                Circle()
                                    .stroke(MixNotesDesign.charcoal.opacity(0.6), lineWidth: 1)
                            )
                    }
                    .scaleEffect(1.15)

                    Button(action: { viewModel.goForward(by: 15) }) {
                        ZStack {
                            Image(systemName: "goforward")
                            Text("15")
                                .font(.system(size: 10, weight: .bold))
                                .offset(x: 0, y: 1)
                        }
                    }

                    Button(action: { viewModel.toggleRepeat() }) {
                        Image(systemName: "repeat")
                            .foregroundColor(viewModel.isRepeating ? MixNotesDesign.charcoal : MixNotesDesign.warmGray)
                    }
                }
                .foregroundColor(MixNotesDesign.charcoal)
                .frame(width: geometry.size.width * 0.8)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 34)
            .font(.title2)
            .buttonStyle(PlainButtonStyle())

            HStack(spacing: 10) {
                Text(timeString(from: viewModel.currentTime))
                    .font(MixNotesDesign.sfFont(16))
                    .monospacedDigit()
                    .foregroundColor(MixNotesDesign.charcoal)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(MixNotesDesign.lightTaupe)
                            .frame(height: 1)

                        Rectangle()
                            .fill(MixNotesDesign.mediumTaupe)
                            .frame(width: geometry.size.width * viewModel.progress, height: 1)

                        Circle()
                            .fill(MixNotesDesign.charcoal)
                            .frame(width: 8, height: 8)
                            .offset(x: geometry.size.width * viewModel.progress - 4)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let progress = max(0, min(1, value.location.x / geometry.size.width))
                                viewModel.currentTime = progress * viewModel.duration
                                viewModel.progress = progress
                            }
                            .onEnded { value in
                                let progress = max(0, min(1, value.location.x / geometry.size.width))
                                viewModel.seek(to: progress)
                            }
                    )
                }
                .frame(height: 10)

                Text(timeString(from: viewModel.duration))
                    .font(MixNotesDesign.sfFont(16))
                    .monospacedDigit()
                    .foregroundColor(MixNotesDesign.warmGray)
            }
            .padding(.horizontal, 24)
            .padding(.top, -8)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AnnotationType.allCases, id: \.self) { type in
                    Button {
                        if type == .custom {
                            pendingCustomTimestamp = viewModel.currentAnnotationTimestamp()
                            showingCustomAnnotation = true
                        } else if type == .tooLoud || type == .tooQuiet {
                            selectedAnnotationType = type
                            showingInstrumentPicker = true
                        } else {
                            viewModel.addAnnotation(type)
                        }
                    } label: {
                        Text(type.rawValue)
                            .font(MixNotesDesign.sfFont(14))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(MixNotesDesign.charcoal)
                            .foregroundColor(MixNotesDesign.cream)
                            .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal)
            .confirmationDialog("Select Instrument", isPresented: $showingInstrumentPicker, titleVisibility: .visible) {
                ForEach(instrumentTypes, id: \.self) { instrument in
                    Button(instrument) {
                        if let type = selectedAnnotationType {
                            viewModel.addAnnotation(type, customText: instrument)
                        }
                    }
                }
            }
            .alert("Custom Annotation", isPresented: $showingCustomAnnotation) {
                TextField("Enter note", text: $customAnnotationText)
                Button("Cancel", role: .cancel) {
                    customAnnotationText = ""
                    pendingCustomTimestamp = nil
                }
                Button("Add") {
                    viewModel.addAnnotation(.custom, customText: customAnnotationText, timestamp: pendingCustomTimestamp)
                    customAnnotationText = ""
                    pendingCustomTimestamp = nil
                }
            } message: {
                Text("Enter a custom note for this timestamp")
            }

            List {
                ForEach(viewModel.annotations.sorted(by: { $0.timestamp < $1.timestamp })) { annotation in
                    HStack {
                        Text(timeString(from: annotation.timestamp))
                            .font(MixNotesDesign.sfFont(15))
                            .monospacedDigit()
                            .foregroundColor(MixNotesDesign.charcoal)
                        Spacer()
                        if annotation.type == .custom, let customText = annotation.customText {
                            Text("Custom: \(customText)")
                                .font(MixNotesDesign.sfItalic(15))
                                .foregroundColor(MixNotesDesign.darkTaupe)
                        } else if let customText = annotation.customText {
                            Text("\(annotation.type.rawValue): \(customText)")
                                .font(MixNotesDesign.sfFont(15))
                                .foregroundColor(MixNotesDesign.darkTaupe)
                        } else {
                            Text(annotation.type.rawValue)
                                .font(MixNotesDesign.sfFont(15))
                                .foregroundColor(MixNotesDesign.darkTaupe)
                        }
                    }
                    .listRowBackground(MixNotesDesign.cream)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteAnnotation(annotation)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .background(MixNotesDesign.cream)
        }
        .background(MixNotesDesign.cream)
    }

    private var chordsPlaybackView: some View {
        VStack(spacing: 16) {
            Text(chordsViewModel.currentFileName)
                .font(MixNotesDesign.sfFont(17, weight: .medium))
                .foregroundColor(MixNotesDesign.charcoal)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            GeometryReader { geometry in
                HStack(spacing: 34) {
                    Button(action: { chordsViewModel.goToBeginning() }) {
                        Image(systemName: "backward.end.fill")
                    }

                    Button(action: { chordsViewModel.goBackward(by: 3) }) {
                        ZStack {
                            Image(systemName: "gobackward")
                            Text("3")
                                .font(.system(size: 10, weight: .bold))
                                .offset(x: 0.3, y: 1)
                        }
                    }

                    Button(action: { chordsViewModel.togglePlayback() }) {
                        Image(systemName: chordsViewModel.isPlaying ? "pause.fill" : "play.fill")
                            .padding(8)
                            .background(
                                Circle()
                                    .stroke(MixNotesDesign.charcoal.opacity(0.6), lineWidth: 1)
                            )
                    }
                    .scaleEffect(1.15)

                    Button(action: { chordsViewModel.goForward(by: 15) }) {
                        ZStack {
                            Image(systemName: "goforward")
                            Text("15")
                                .font(.system(size: 10, weight: .bold))
                                .offset(x: 0, y: 1)
                        }
                    }

                    Button(action: { chordsViewModel.toggleRepeat() }) {
                        Image(systemName: "repeat")
                            .foregroundColor(chordsViewModel.isRepeating ? MixNotesDesign.charcoal : MixNotesDesign.warmGray)
                    }
                }
                .foregroundColor(MixNotesDesign.charcoal)
                .frame(width: geometry.size.width * 0.8)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 34)
            .font(.title2)
            .buttonStyle(PlainButtonStyle())

            HStack(spacing: 10) {
                Text(timeString(from: chordsViewModel.currentTime))
                    .font(MixNotesDesign.sfFont(16))
                    .monospacedDigit()
                    .foregroundColor(MixNotesDesign.charcoal)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(MixNotesDesign.lightTaupe)
                            .frame(height: 1)

                        Rectangle()
                            .fill(MixNotesDesign.mediumTaupe)
                            .frame(width: geometry.size.width * chordsViewModel.progress, height: 1)

                        Circle()
                            .fill(MixNotesDesign.charcoal)
                            .frame(width: 8, height: 8)
                            .offset(x: geometry.size.width * chordsViewModel.progress - 4)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let progress = max(0, min(1, value.location.x / geometry.size.width))
                                chordsViewModel.currentTime = progress * chordsViewModel.duration
                                chordsViewModel.progress = progress
                            }
                            .onEnded { value in
                                let progress = max(0, min(1, value.location.x / geometry.size.width))
                                chordsViewModel.seek(to: progress)
                            }
                    )
                }
                .frame(height: 10)

                Text(timeString(from: chordsViewModel.duration))
                    .font(MixNotesDesign.sfFont(16))
                    .monospacedDigit()
                    .foregroundColor(MixNotesDesign.warmGray)
            }
            .padding(.horizontal, 24)
            .padding(.top, -8)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Key")
                        .font(MixNotesDesign.sfFont(16, weight: .medium))
                        .foregroundColor(MixNotesDesign.charcoal)
                    Text(currentKeyDisplayName)
                        .font(MixNotesDesign.sfItalic(16))
                        .foregroundColor(MixNotesDesign.darkTaupe)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isMinorKey.toggle()
                        }
                    } label: {
                        Text("Minor")
                            .font(.custom("LeagueSpartan-Bold", size: 13))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isMinorKey ? MixNotesDesign.charcoal : MixNotesDesign.cream)
                            .foregroundColor(isMinorKey ? MixNotesDesign.cream : MixNotesDesign.charcoal)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isNashvilleMode)
                    .opacity(isNashvilleMode ? 0.5 : 1)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isNashvilleMode.toggle()
                        }
                    } label: {
                        Text("Nashville")
                            .font(.custom("LeagueSpartan-Bold", size: 13))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isNashvilleMode ? MixNotesDesign.charcoal : MixNotesDesign.cream)
                            .foregroundColor(isNashvilleMode ? MixNotesDesign.cream : MixNotesDesign.charcoal)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                GeometryReader { geometry in
                    Slider(value: $selectedKeyIndex, in: 0...Double(keyNames.count - 1), step: 1)
                        .tint(MixNotesDesign.charcoal)
                        .frame(width: geometry.size.width * 0.9)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 24)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)

            LazyVGrid(columns: chordColumns, spacing: 8) {
                ForEach(chordFormulas.indices, id: \.self) { index in
                    let label = chordLabel(for: chordFormulas[index], index: index)
                    let isSecondRow = index >= majorChordsRow1.count
                    Button {
                        if isEditMode {
                            guard isSecondRow else { return }
                            editingChordIndex = index
                            editingChordText = label
                        } else {
                            let slot = nextAvailableSlot(
                                fromBar: nextPlacementBar,
                                fromBeat: nextPlacementBeat,
                                allowHalf: isDoublePlacement
                            )
                            chordsViewModel.addAnnotation(
                                .custom,
                                customText: label,
                                chordIndex: index,
                                barIndex: slot.bar,
                                beatIndex: slot.beat
                            )
                            let nextSlot = nextAvailableSlot(
                                fromBar: slot.bar,
                                fromBeat: slot.beat + 1,
                                allowHalf: isDoublePlacement
                            )
                            nextPlacementBar = nextSlot.bar
                            nextPlacementBeat = nextSlot.beat
                            lastPlacedBar = slot.bar
                            lastPlacedBeat = slot.beat
                        }
                    } label: {
                        Text(label)
                            .font(.custom("LeagueSpartan-Bold", size: 12))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(MixNotesDesign.warmWhite)
                            .foregroundColor(MixNotesDesign.charcoal)
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(MixNotesDesign.lightTaupe, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
            .alert("Edit Chord", isPresented: Binding(
                get: { editingChordIndex != nil },
                set: { isPresented in
                    if !isPresented {
                        editingChordIndex = nil
                        editingChordText = ""
                    }
                }
            )) {
                TextField("Chord label", text: $editingChordText)
                Button("Cancel", role: .cancel) {
                    editingChordIndex = nil
                    editingChordText = ""
                }
                Button("Save") {
                    if let index = editingChordIndex {
                        let trimmed = editingChordText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            chordOverrides.removeValue(forKey: index)
                        } else {
                            chordOverrides[index] = AudioAnnotationViewModel.ChordOverride(
                                label: trimmed,
                                keyIndex: currentKeyIndex
                            )
                        }
                        chordsViewModel.saveChordOverrides(chordOverrides)
                        updateChordAnnotationsForKeyChange()
                    }
                    editingChordIndex = nil
                    editingChordText = ""
                }
            }

            HStack(spacing: 10) {
                Button {
                    deleteLastChordAnnotation()
                } label: {
                    Text("Delete")
                        .font(.custom("LeagueSpartan-Bold", size: 13))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(MixNotesDesign.cream)
                        .foregroundColor(MixNotesDesign.charcoal)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    addSkippedBar()
                } label: {
                    Text("Skip")
                        .font(.custom("LeagueSpartan-Bold", size: 13))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(MixNotesDesign.cream)
                        .foregroundColor(MixNotesDesign.charcoal)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isDoublePlacement.toggle()
                    }
                } label: {
                    Text("Double")
                        .font(.custom("LeagueSpartan-Bold", size: 13))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isDoublePlacement ? MixNotesDesign.charcoal : MixNotesDesign.cream)
                        .foregroundColor(isDoublePlacement ? MixNotesDesign.cream : MixNotesDesign.charcoal)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isEditMode.toggle()
                    }
                } label: {
                    Text("Edit")
                        .font(.custom("LeagueSpartan-Bold", size: 13))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isEditMode ? MixNotesDesign.charcoal : MixNotesDesign.cream)
                        .foregroundColor(isEditMode ? MixNotesDesign.cream : MixNotesDesign.charcoal)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("Chord Chart")
                    .font(MixNotesDesign.sfFont(16, weight: .medium))
                    .foregroundColor(MixNotesDesign.charcoal)
                    .padding(.horizontal)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(0..<chordChartLineCount, id: \.self) { line in
                            chordChartLineView(line)
                                .padding(.horizontal)
                        }
                    }
                }
                .frame(maxHeight: 240)
                .background(MixNotesDesign.cream)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(MixNotesDesign.cream)
    }

    @ViewBuilder
    private var audioListView: some View {
        List {
            Section {
                Button {
                    openSharedDocuments()
                } label: {
                    Label {
                        Text("Add Audio File")
                            .font(MixNotesDesign.sfFont(16))
                            .foregroundColor(MixNotesDesign.charcoal)
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(MixNotesDesign.charcoal)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(MixNotesDesign.cream)

                if viewModel.storedAudioFiles.isEmpty {
                    Text("Imported audio files will appear here.")
                        .font(MixNotesDesign.sfItalic(14))
                        .foregroundColor(MixNotesDesign.warmGray)
                        .padding(.vertical, 4)
                        .listRowBackground(MixNotesDesign.cream)
                } else {
                    ForEach(viewModel.storedAudioFiles.sorted(by: { $0.dateAdded > $1.dateAdded })) { storedFile in
                        if mode == .ab {
                            abSelectionRow(for: storedFile)
                        } else if mode == .chords {
                            chordsStoredFileRow(for: storedFile)
                        } else {
                            mixStoredFileRow(for: storedFile)
                        }
                    }
                }
            } header: {
                Text("Recents")
                    .font(MixNotesDesign.sfFont(17, weight: .medium))
                    .foregroundColor(MixNotesDesign.charcoal)
                    .textCase(nil)
            }

            if mode == .ab {
                ABMusicLibrarySection(
                    libraryManager: libraryManager,
                    slotForSong: abViewModel.slot(for:)
                ) { song in
                    withAnimation(abSelectionAnimation) {
                        abViewModel.selectLibrarySong(song)
                    }
                }
            } else if mode == .chords {
                MusicLibrarySection(libraryManager: libraryManager) { song in
                    chordsViewModel.loadLibrarySong(song)
                }
            } else {
                MusicLibrarySection(libraryManager: libraryManager) { song in
                    viewModel.loadLibrarySong(song)
                }
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(MixNotesDesign.cream)
    }

    private func mixStoredFileRow(for storedFile: StoredAudioFile) -> some View {
        Button {
            viewModel.loadStoredAudio(storedFile)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(storedFile.displayName)
                        .font(MixNotesDesign.sfFont(16, weight: .medium))
                        .foregroundColor(MixNotesDesign.charcoal)
                    Text("Added: \(storedFile.formattedDate)")
                        .font(MixNotesDesign.sfFont(13))
                        .foregroundColor(MixNotesDesign.warmGray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(storedFile.formattedDuration)
                        .font(MixNotesDesign.sfFont(13))
                        .foregroundColor(MixNotesDesign.warmGray)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowBackground(MixNotesDesign.cream)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteStoredFile(storedFile)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func chordsStoredFileRow(for storedFile: StoredAudioFile) -> some View {
        Button {
            chordsViewModel.loadStoredAudio(storedFile)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(storedFile.displayName)
                        .font(MixNotesDesign.sfFont(16, weight: .medium))
                        .foregroundColor(MixNotesDesign.charcoal)
                    Text("Added: \(storedFile.formattedDate)")
                        .font(MixNotesDesign.sfFont(13))
                        .foregroundColor(MixNotesDesign.warmGray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(storedFile.formattedDuration)
                        .font(MixNotesDesign.sfFont(13))
                        .foregroundColor(MixNotesDesign.warmGray)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowBackground(MixNotesDesign.cream)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteStoredFile(storedFile)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func abSelectionRow(for storedFile: StoredAudioFile) -> some View {
        let slot = abViewModel.slot(for: storedFile)

        return Button {
            withAnimation(abSelectionAnimation) {
                abViewModel.selectStoredFile(storedFile)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(storedFile.displayName)
                        .font(MixNotesDesign.sfFont(16, weight: .medium))
                        .foregroundColor(MixNotesDesign.charcoal)
                    Text("Added: \(storedFile.formattedDate)")
                        .font(MixNotesDesign.sfFont(13))
                        .foregroundColor(MixNotesDesign.warmGray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(storedFile.formattedDuration)
                        .font(MixNotesDesign.sfFont(13))
                        .foregroundColor(MixNotesDesign.warmGray)
                }
            }
            .padding(.vertical, 4)
            .padding(.leading, slot == nil ? 0 : 28)
        }
        .buttonStyle(.plain)
        .listRowBackground(MixNotesDesign.cream)
        .overlay(alignment: .leading) {
            if let slot {
                selectionBadge(for: slot)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteStoredFile(storedFile)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .animation(abSelectionAnimation, value: slot)
    }

    private func selectionBadge(for slot: ABAudioAnnotationViewModel.AudioSlot) -> some View {
        Text(slot.displayLabel)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(MixNotesDesign.cream)
            .frame(width: 22, height: 22)
            .background(Circle().fill(MixNotesDesign.charcoal))
    }

    private func handleRecentsTapped() {
        if isShowingABPlayback {
            abViewModel.reset()
        } else if isShowingChordsPlayback {
            chordsViewModel.reset()
        } else {
            viewModel.reset()
            mode = .mix
        }
    }

    private var shouldShowBanner: Bool {
        guard !currentLoadingState, !isShowingABPlayback else {
            return false
        }

        if isShowingMixPlayback {
            return true
        }

        return !viewModel.storedAudioFiles.isEmpty
    }

    private func deleteStoredFile(_ storedFile: StoredAudioFile) {
        viewModel.deleteStoredFile(storedFile)
        chordsViewModel.deleteAnnotations(for: storedFile)
    }

    private func chordLabel(for formula: ChordFormula, index: Int) -> String {
        if let override = chordOverrides[index] {
            return transposedOverrideLabel(override)
        }
        switch keyLabelMode {
        case .notes:
            let baseIndex = min(max(Int(selectedKeyIndex), 0), keyNames.count - 1)
            let rootIndex = (baseIndex + formula.offset) % keyNames.count
            return keyNames[rootIndex] + formula.quality.suffix
        case .nashville:
            return nashvilleLabel(for: formula)
        }
    }

    private func transposedOverrideLabel(_ override: AudioAnnotationViewModel.ChordOverride) -> String {
        if keyLabelMode == .nashville {
            return nashvilleLabelFromChordLabel(override.label, sourceKeyIndex: override.keyIndex)
        }
        let maxKeyIndex = keyNames.count - 1
        guard override.keyIndex >= 0,
              override.keyIndex < maxKeyIndex,
              currentKeyIndex < maxKeyIndex
        else {
            return override.label
        }

        let shift = currentKeyIndex - override.keyIndex
        return transposeChordLabel(override.label, by: shift)
    }

    private func nashvilleLabelFromChordLabel(_ label: String, sourceKeyIndex: Int) -> String {
        let shift = currentKeyIndex - sourceKeyIndex
        let transposedLabel = transposeChordLabel(label, by: shift)
        let parts = transposedLabel.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard let rootPart = nashvillePart(from: String(parts[0]), includeRemainder: true) else {
            return label
        }
        if parts.count == 2, let bassPart = nashvillePart(from: String(parts[1]), includeRemainder: false) {
            return "\(rootPart)/\(bassPart)"
        }
        return rootPart
    }

    private func nashvillePart(from part: String, includeRemainder: Bool) -> String? {
        guard let first = part.first, "ABCDEFG".contains(first) else { return nil }
        var index = part.startIndex
        let rootLetter = String(part[index])
        index = part.index(after: index)

        var accidental = ""
        if index < part.endIndex {
            let char = part[index]
            if char == "#" || char == "b" {
                accidental = String(char)
                index = part.index(after: index)
            }
        }

        let rootToken = rootLetter + accidental
        guard let semitone = noteSemitone(rootToken) else { return nil }
        let keySemitone = noteSemitone(currentKeyName) ?? currentKeyIndex
        let offset = (semitone - keySemitone + 12) % 12
        let degree = nashvilleDegree(for: offset)
        if includeRemainder {
            let remainder = String(part[index...])
            return degree + remainder
        }
        return degree
    }

    private func nashvilleDegree(for semitoneOffset: Int) -> String {
        switch semitoneOffset {
        case 0: return "1"
        case 2: return "2"
        case 4: return "3"
        case 5: return "4"
        case 7: return "5"
        case 9: return "6"
        case 11: return "7"
        default: return "?"
        }
    }

    private func transposeChordLabel(_ label: String, by shift: Int) -> String {
        guard shift != 0 else { return label }
        let parts = label.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard let transposedRoot = transposeChordPart(String(parts[0]), by: shift) else {
            return label
        }
        if parts.count == 2, let transposedBass = transposeChordPart(String(parts[1]), by: shift) {
            return "\(transposedRoot)/\(transposedBass)"
        }
        return transposedRoot
    }

    private func transposeChordPart(_ part: String, by shift: Int) -> String? {
        guard let first = part.first, "ABCDEFG".contains(first) else { return nil }
        var index = part.startIndex
        let rootLetter = String(part[index])
        index = part.index(after: index)

        var accidental = ""
        if index < part.endIndex {
            let char = part[index]
            if char == "#" || char == "b" {
                accidental = String(char)
                index = part.index(after: index)
            }
        }

        let rootToken = rootLetter + accidental
        guard let semitone = noteSemitone(rootToken) else { return nil }
        let transposed = noteName(for: semitone + shift)
        let remainder = String(part[index...])
        return transposed + remainder
    }

    private func noteSemitone(_ note: String) -> Int? {
        switch note {
        case "C": return 0
        case "C#": return 1
        case "Db": return 1
        case "D": return 2
        case "D#": return 3
        case "Eb": return 3
        case "E": return 4
        case "F": return 5
        case "F#": return 6
        case "Gb": return 6
        case "G": return 7
        case "G#": return 8
        case "Ab": return 8
        case "A": return 9
        case "A#": return 10
        case "Bb": return 10
        case "B": return 11
        default: return nil
        }
    }

    private func noteName(for semitone: Int) -> String {
        let names = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
        let index = ((semitone % 12) + 12) % 12
        return names[index]
    }

    private func nashvilleLabel(for formula: ChordFormula) -> String {
        let degree: String
        switch formula.offset {
        case 0: degree = "1"
        case 2: degree = "2"
        case 4: degree = "3"
        case 5: degree = "4"
        case 7: degree = "5"
        case 9: degree = "6"
        case 11: degree = "7"
        default: degree = "?"
        }

        switch formula.quality {
        case .major:
            return degree
        case .minor:
            return "\(degree)m"
        case .diminished:
            return "\(degree)dim"
        case .dominant7:
            return "\(degree)7"
        case .major7:
            return "\(degree)maj7"
        case .minor7:
            return "\(degree)m7"
        case .add9:
            return "\(degree)add9"
        }
    }

    private func updateChordAnnotationsForKeyChange() {
        guard chordsViewModel.hasLoadedAudio else { return }
        let updated = chordsViewModel.annotations.map { annotation in
            guard let index = annotation.chordIndex else { return annotation }
            guard index >= 0 && index < chordFormulas.count else { return annotation }
            let label = chordLabel(for: chordFormulas[index], index: index)
            return AudioAnnotation(
                id: annotation.id,
                timestamp: annotation.timestamp,
                type: annotation.type,
                customText: label,
                chordIndex: annotation.chordIndex,
                barIndex: annotation.barIndex,
                beatIndex: annotation.beatIndex
            )
        }
        chordsViewModel.replaceAnnotations(updated)
    }

    private func normalizeChordAnnotationsForChart() {
        guard chordsViewModel.hasLoadedAudio else { return }
        var updated = chordsViewModel.annotations
        var usedSlots = Set<String>()
        var nextBar = 0
        var didChange = false

        for index in updated.indices {
            guard updated[index].chordIndex != nil else { continue }
            let bar = updated[index].barIndex
            let beat = updated[index].beatIndex
            if let bar, let beat {
                let clampedBeat = min(max(beat, 0), beatsPerBar - 1)
                if clampedBeat != beat {
                    let annotation = updated[index]
                    updated[index] = AudioAnnotation(
                        id: annotation.id,
                        timestamp: annotation.timestamp,
                        type: annotation.type,
                        customText: annotation.customText,
                        chordIndex: annotation.chordIndex,
                        barIndex: bar,
                        beatIndex: clampedBeat
                    )
                    didChange = true
                }
                usedSlots.insert(slotKey(bar: bar, beat: clampedBeat))
                continue
            }

            while usedSlots.contains(slotKey(bar: nextBar, beat: 0)) {
                nextBar += 1
            }

            let annotation = updated[index]
            updated[index] = AudioAnnotation(
                id: annotation.id,
                timestamp: annotation.timestamp,
                type: annotation.type,
                customText: annotation.customText,
                chordIndex: annotation.chordIndex,
                barIndex: nextBar,
                beatIndex: 0
            )
            usedSlots.insert(slotKey(bar: nextBar, beat: 0))
            nextBar += 1
            didChange = true
        }

        if didChange {
            chordsViewModel.replaceAnnotations(updated)
        }
    }

    private func nextAvailableSlot(fromBar: Int, fromBeat: Int, allowHalf: Bool) -> (bar: Int, beat: Int) {
        let usedSlots = Set(chordsViewModel.annotations.compactMap { annotation -> String? in
            guard let bar = annotation.barIndex, let beat = annotation.beatIndex else { return nil }
            return slotKey(bar: bar, beat: beat)
        })

        let beatOptions = allowHalf ? [0, 1] : [0]
        var bar = max(fromBar, 0)
        var beatIndex = fromBeat

        while bar <= chordChartBars + 50 {
            for beat in beatOptions {
                if bar == fromBar, beat < beatIndex {
                    continue
                }
                if !usedSlots.contains(slotKey(bar: bar, beat: beat)) {
                    return (bar, beat)
                }
            }
            bar += 1
            beatIndex = 0
        }

        return (chordChartBars, 0)
    }

    private func chordBarView(bar: Int, beatWidth: CGFloat, beatSpacing: CGFloat, barWidth: CGFloat) -> some View {
        HStack(spacing: beatSpacing) {
            ForEach(0..<beatsPerBar, id: \.self) { beat in
                chordBeatSlotView(bar: bar, beat: beat, width: beatWidth)
            }
        }
        .padding(.horizontal, 6)
        .frame(width: barWidth, alignment: .leading)
    }

    private func chordBeatSlotView(bar: Int, beat: Int, width: CGFloat) -> some View {
        let annotation = chordAnnotation(for: bar, beat: beat)

        return ZStack {
            if let annotation, let label = annotation.customText {
                HStack(spacing: 2) {
                    Text(label)
                        .font(.custom("LeagueSpartan-Bold", size: 11))
                        .foregroundColor(MixNotesDesign.charcoal)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 3)
                .onDrag {
                    NSItemProvider(object: annotation.id.uuidString as NSString)
                }
            }
        }
        .frame(width: width, height: 26)
        .contentShape(Rectangle())
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
            handleChordDrop(providers: providers, bar: bar, beat: beat)
        }
        .contextMenu {
            if let annotation {
                Button(role: .destructive) {
                    chordsViewModel.deleteAnnotation(annotation)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func chordAnnotation(for bar: Int, beat: Int) -> AudioAnnotation? {
        chordsViewModel.annotations.first { annotation in
            annotation.barIndex == bar && annotation.beatIndex == beat
        }
    }

    private func chordChartLineView(_ line: Int) -> some View {
        let bars = barsForLine(line)

        return GeometryReader { geometry in
            let barCount = max(bars.count, 1)
            let barlineWidth: CGFloat = 1
            let beatSpacing: CGFloat = 6
            let totalBarlineWidth = barlineWidth * CGFloat(barCount + 1)
            let availableWidth = max(geometry.size.width - totalBarlineWidth, 0)
            let barWidth = availableWidth / CGFloat(barCount)
            let beatWidth = max(18, (barWidth - (beatSpacing * CGFloat(beatsPerBar - 1)) - 10) / CGFloat(beatsPerBar))

            HStack(spacing: 0) {
                barline
                ForEach(bars, id: \.self) { bar in
                    chordBarView(bar: bar, beatWidth: beatWidth, beatSpacing: beatSpacing, barWidth: barWidth)
                    barline
                }
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .frame(height: 30)
    }

    private var barline: some View {
        Rectangle()
            .fill(MixNotesDesign.mediumTaupe)
            .frame(width: 1)
    }

    private var chordChartLineCount: Int {
        Int(ceil(Double(chordChartBars) / Double(barsPerLine)))
    }

    private func barsForLine(_ line: Int) -> [Int] {
        let start = line * barsPerLine
        let end = min(start + barsPerLine, chordChartBars)
        return start < end ? Array(start..<end) : []
    }

    private func deleteLastChordAnnotation() {
        let sorted = chordsViewModel.annotations.sorted { lhs, rhs in
            let lhsBar = lhs.barIndex ?? -1
            let rhsBar = rhs.barIndex ?? -1
            if lhsBar != rhsBar {
                return lhsBar > rhsBar
            }
            let lhsBeat = lhs.beatIndex ?? -1
            let rhsBeat = rhs.beatIndex ?? -1
            if lhsBeat != rhsBeat {
                return lhsBeat > rhsBeat
            }
            return lhs.timestamp > rhs.timestamp
        }

        if let last = sorted.first {
            chordsViewModel.deleteAnnotation(last)
            if let bar = last.barIndex, let beat = last.beatIndex {
                nextPlacementBar = bar
                nextPlacementBeat = beat
                lastPlacedBar = bar
                lastPlacedBeat = beat
            }
        }
    }

    private func addSkippedBar() {
        let slot = nextAvailableSlot(
            fromBar: nextPlacementBar,
            fromBeat: nextPlacementBeat,
            allowHalf: isDoublePlacement
        )
        chordsViewModel.addAnnotation(
            .custom,
            customText: nil,
            chordIndex: nil,
            barIndex: slot.bar,
            beatIndex: slot.beat
        )
        let nextSlot = nextAvailableSlot(
            fromBar: slot.bar,
            fromBeat: slot.beat + 1,
            allowHalf: isDoublePlacement
        )
        nextPlacementBar = nextSlot.bar
        nextPlacementBeat = nextSlot.beat
        lastPlacedBar = slot.bar
        lastPlacedBeat = slot.beat
    }

    private func exportChordChart() -> String {
        let header = "Chord Chart - \(currentKeyDisplayName)"
        let totalBars = max(1, chordChartBars)
        let barCountPerLine = barsPerLine
        var lines: [String] = [header, ""]

        let annotationsBySlot = Dictionary(
            chordsViewModel.annotations.compactMap { annotation -> (BarBeatSlot, String)? in
                guard let bar = annotation.barIndex, let beat = annotation.beatIndex else { return nil }
                let label = annotation.customText ?? ""
                return (BarBeatSlot(bar: bar, beat: beat), label)
            },
            uniquingKeysWith: { first, _ in first }
        )

        let barLabelWidth = 6
        let beatSpacing = " "
        let barPadding = " "
        let beatSlots = beatsPerBar

        let lineCount = Int(ceil(Double(totalBars) / Double(barCountPerLine)))
        for line in 0..<lineCount {
            let start = line * barCountPerLine
            let end = min(start + barCountPerLine, totalBars)
            var lineText = "|"
            for bar in start..<end {
                var barParts: [String] = []
                for beat in 0..<beatSlots {
                    let label = annotationsBySlot[BarBeatSlot(bar: bar, beat: beat)] ?? ""
                    let padded = label.padding(toLength: barLabelWidth, withPad: " ", startingAt: 0)
                    barParts.append(padded)
                }
                lineText += barPadding + barParts.joined(separator: beatSpacing) + barPadding + "|"
            }
            lines.append(lineText)
        }

        return lines.joined(separator: "\n")
    }


    private func handleChordDrop(providers: [NSItemProvider], bar: Int, beat: Int) -> Bool {
        guard let provider = providers.first else { return false }
        let typeIdentifier = UTType.text.identifier
        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
            var idString: String?
            if let data = item as? Data {
                idString = String(data: data, encoding: .utf8)
            } else if let string = item as? String {
                idString = string
            } else if let nsString = item as? NSString {
                idString = nsString as String
            }

            guard let idString, let id = UUID(uuidString: idString) else { return }
            DispatchQueue.main.async {
                moveChordAnnotation(id: id, to: bar, beat: beat)
            }
        }
        return true
    }

    private func moveChordAnnotation(id: UUID, to bar: Int, beat: Int) {
        var updated = chordsViewModel.annotations
        updated.removeAll { $0.id != id && $0.barIndex == bar && $0.beatIndex == beat }
        if let index = updated.firstIndex(where: { $0.id == id }) {
            let annotation = updated[index]
            updated[index] = AudioAnnotation(
                id: annotation.id,
                timestamp: annotation.timestamp,
                type: annotation.type,
                customText: annotation.customText,
                chordIndex: annotation.chordIndex,
                barIndex: bar,
                beatIndex: beat
            )
            chordsViewModel.replaceAnnotations(updated)
        }
    }

    private func slotKey(bar: Int, beat: Int) -> String {
        "\(bar)-\(beat)"
    }

    private func openSharedDocuments() {
        if let url = URL(string: "shareddocuments://") {
            UIApplication.shared.open(url)
        }
    }

    private func timeString(from timeInterval: TimeInterval) -> String {
        let time = abs(timeInterval)
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let sign = timeInterval < 0 ? "-" : ""
        return String(format: "%@%02d:%02d", sign, minutes, seconds)
    }
}
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct BannerAdView: View {
    let adUnitID: String
    @State private var containerWidth: CGFloat = UIScreen.main.bounds.width

    var body: some View {
        BannerContainer(
            adUnitID: adUnitID,
            width: containerWidth
        )
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { updateWidth(geometry.size.width) }
                    .onChange(of: geometry.size.width) { oldWidth, newWidth in
                        updateWidth(newWidth)
                    }
            }
        )
    }

    private func updateWidth(_ newWidth: CGFloat) {
        let adjustedWidth = max(newWidth, 320)
        if abs(Double(adjustedWidth - containerWidth)) > .ulpOfOne {
            containerWidth = adjustedWidth
        }
    }
}

private struct BannerContainer: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .clear

        let size = adaptiveSize(for: width)
        let banner = GADBannerView(adSize: size)
        banner.adUnitID = adUnitID
        banner.rootViewController = rootViewController()
        banner.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(banner)

        let centerX = banner.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        let top = banner.topAnchor.constraint(equalTo: container.topAnchor)
        let bottom = banner.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        let widthConstraint = banner.widthAnchor.constraint(equalToConstant: size.size.width)

        NSLayoutConstraint.activate([centerX, top, bottom, widthConstraint])

        context.coordinator.bannerView = banner
        context.coordinator.widthConstraint = widthConstraint

        banner.load(GADRequest())

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let banner = context.coordinator.bannerView else { return }
        let size = adaptiveSize(for: width)

        if !GADAdSizeEqualToSize(banner.adSize, size) {
            banner.adSize = size
            banner.load(GADRequest())
        }

        if let controller = rootViewController(), banner.rootViewController !== controller {
            banner.rootViewController = controller
        }

        if banner.adUnitID != adUnitID {
            banner.adUnitID = adUnitID
            banner.load(GADRequest())
        }

        if let widthConstraint = context.coordinator.widthConstraint, abs(Double(widthConstraint.constant - size.size.width)) > .ulpOfOne {
            widthConstraint.constant = size.size.width
        }
    }

    private func adaptiveSize(for width: CGFloat) -> GADAdSize {
        let validWidth = max(width, 320)
        return GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(validWidth)
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    }

    final class Coordinator {
        var bannerView: GADBannerView?
        var widthConstraint: NSLayoutConstraint?
    }
}

#Preview {
    ContentView(viewModel: AudioAnnotationViewModel.preview)
}
