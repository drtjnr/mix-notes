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
    // Cool gray color palette
    static let cream = Color(red: 247/255, green: 248/255, blue: 249/255)
    static let warmWhite = Color(red: 252/255, green: 252/255, blue: 253/255)
    static let charcoal = Color(red: 23/255, green: 30/255, blue: 45/255)
    static let warmGray = Color(red: 120/255, green: 125/255, blue: 135/255)
    static let lightTaupe = Color(red: 210/255, green: 213/255, blue: 218/255)
    static let mediumTaupe = Color(red: 170/255, green: 175/255, blue: 183/255)
    static let darkTaupe = Color(red: 80/255, green: 86/255, blue: 98/255)

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
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Group {
                        if isOn {
                            LinearGradient(
                                colors: [MixNotesDesign.charcoal, MixNotesDesign.charcoal.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            LinearGradient(
                                colors: [MixNotesDesign.cream, MixNotesDesign.cream],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                )
                .foregroundColor(isOn ? .white : MixNotesDesign.charcoal)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(isOn ? 0.15 : 0.05), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct ContentView: View {
    @StateObject private var viewModel: AudioAnnotationViewModel
    @StateObject private var abViewModel = ABAudioAnnotationViewModel()
    @StateObject private var libraryManager = LibraryManager()
    @ObservedObject private var repeatStateManager = RepeatStateManager.shared
    @State private var showingShareSheet = false
    @State private var showingCustomAnnotation = false
    @State private var pendingCustomTimestamp: TimeInterval?
    @State private var showingInstrumentPicker = false
    @State private var selectedAnnotationType: AnnotationType?
    @State private var mode: AppMode = .mix

    let instrumentTypes = ["Vocals", "Bass", "Guitar / Keys", "Drums"]
    let columns = Array(repeating: GridItem(.flexible()), count: 3)
    private let abSelectionAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7)

    private enum AppMode {
        case mix
        case ab
    }

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

    private var isShowingList: Bool {
        !isShowingABPlayback && !isShowingMixPlayback && !currentLoadingState
    }

    private var currentLoadingState: Bool {
        switch mode {
        case .ab:
            return abViewModel.isLoadingFromBrowse
        case .mix:
            return viewModel.isLoadingFromBrowse
        }
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
    }

    @ViewBuilder
    private var titleView: some View {
        if isShowingABPlayback {
            ABTitleView()
        } else {
            MixNotesTitleView()
        }
    }

    private var modeToggleButtons: some View {
        ABModeToggleButton(isOn: Binding(
            get: { mode == .ab },
            set: { mode = $0 ? .ab : .mix }
        ))
    }

    private var principalToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            titleView
        }
    }

    private var trailingToolbarItem: some ToolbarContent {
        let shouldShowExport = isShowingMixPlayback
        let shouldShowModeToggle = isShowingList

        return ToolbarItem(placement: .navigationBarTrailing) {
            if shouldShowExport {
                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(MixNotesDesign.charcoal)
                }
            } else if shouldShowModeToggle {
                modeToggleButtons
            }
        }
    }

    private var leadingToolbarItem: some ToolbarContent {
        let shouldShowRecents = isShowingMixPlayback || isShowingABPlayback
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

            HStack(spacing: 0) {
                Spacer()

                // Skip back — lightweight outline
                Button(action: { viewModel.goToBeginning() }) {
                    Image(systemName: "backward.end")
                        .font(.system(size: 22, weight: .light))
                }
                .frame(width: 48, height: 48)

                Spacer()

                // Rewind 3s
                Button(action: { viewModel.goBackward(by: 3) }) {
                    ZStack {
                        Image(systemName: "gobackward")
                            .font(.system(size: 32, weight: .light))
                        Text("3")
                            .font(.system(size: 13, weight: .bold))
                            .offset(x: 0.3, y: 1)
                    }
                }
                .frame(width: 56, height: 56)

                Spacer()

                // Play/Pause
                Button(action: { viewModel.togglePlayback() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .offset(x: viewModel.isPlaying ? 0 : 2)
                }
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .stroke(MixNotesDesign.charcoal, lineWidth: 2)
                )

                Spacer()

                // Forward 15s
                Button(action: { viewModel.goForward(by: 15) }) {
                    ZStack {
                        Image(systemName: "goforward")
                            .font(.system(size: 32, weight: .light))
                        Text("15")
                            .font(.system(size: 13, weight: .bold))
                            .offset(x: 0, y: 1)
                    }
                }
                .frame(width: 56, height: 56)

                Spacer()

                // Repeat — w-12 h-12, icon w-7 h-7
                Button(action: { viewModel.toggleRepeat() }) {
                    Image(systemName: "repeat")
                        .font(.system(size: 22))
                        .foregroundColor(viewModel.isRepeating ? MixNotesDesign.charcoal : MixNotesDesign.warmGray)
                }
                .frame(width: 48, height: 48)

                Spacer()
            }
            .foregroundColor(MixNotesDesign.charcoal)
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)

            HStack(spacing: 12) {
                Text(timeString(from: viewModel.currentTime))
                    .font(MixNotesDesign.sfFont(14, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(MixNotesDesign.darkTaupe)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Track
                        Capsule()
                            .fill(MixNotesDesign.lightTaupe)
                            .frame(height: 4)

                        // Filled portion
                        Capsule()
                            .fill(MixNotesDesign.mediumTaupe)
                            .frame(width: geometry.size.width * viewModel.progress, height: 4)

                        // Thumb
                        Circle()
                            .fill(MixNotesDesign.charcoal)
                            .frame(width: 14, height: 14)
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                            .offset(x: geometry.size.width * viewModel.progress - 7)
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
                .frame(height: 20)

                Text(timeString(from: viewModel.duration))
                    .font(MixNotesDesign.sfFont(14, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(MixNotesDesign.darkTaupe)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 8)

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
                            .font(MixNotesDesign.sfFont(15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [MixNotesDesign.charcoal, MixNotesDesign.charcoal.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
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
            .sheet(isPresented: $showingCustomAnnotation) {
                CustomAnnotationSheet(
                    isPresented: $showingCustomAnnotation,
                    timestamp: pendingCustomTimestamp,
                    onAddText: { text in
                        viewModel.addAnnotation(.custom, customText: text, timestamp: pendingCustomTimestamp)
                        pendingCustomTimestamp = nil
                    },
                    onAddAudioRecording: { text, recordingURL in
                        let fileName = AudioRecorderManager.fileName(from: recordingURL)
                        viewModel.addAnnotation(
                            .custom,
                            customText: text,
                            audioRecordingFileName: fileName,
                            timestamp: pendingCustomTimestamp
                        )
                        pendingCustomTimestamp = nil
                    },
                    onPausePlayback: {
                        viewModel.pauseAudio()
                    },
                    onResumePlayback: {
                        viewModel.playAudio()
                    }
                )
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
                        if annotation.audioRecordingFileName != nil {
                            Button {
                                if viewModel.playingAnnotationId == annotation.id {
                                    viewModel.stopAnnotationPlayback()
                                } else {
                                    viewModel.playAnnotationRecording(annotation)
                                }
                            } label: {
                                Image(systemName: viewModel.playingAnnotationId == annotation.id ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(MixNotesDesign.charcoal)
                            }
                            .buttonStyle(.plain)
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
