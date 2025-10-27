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

struct MixNotesTitleView: View {
    var body: some View {
        Text("mix notes")
            .font(.custom("LeagueSpartan-Bold", size: 20))
            .foregroundColor(.primary)
            .kerning(-0.5)
          
    }
}

struct ContentView: View {
    @StateObject private var viewModel: AudioAnnotationViewModel
    @State private var showingShareSheet = false
    @State private var showingCustomAnnotation = false
    @State private var customAnnotationText = ""
    @State private var showingInstrumentPicker = false
    @State private var selectedAnnotationType: AnnotationType?
    
    let instrumentTypes = ["Vocals", "Bass", "Guitar / Keys", "Drums"]
    let columns = Array(repeating: GridItem(.flexible()), count: 3)

    private enum AdMobIdentifiers {
        static let bannerAdUnitID = "ca-app-pub-2186858726503482/7521622823"
    }
    
    init(viewModel: AudioAnnotationViewModel = AudioAnnotationViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoadingFromBrowse {
                    // Loading state for browse files
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Loading audio file...")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Please wait while we prepare your audio file for playback")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !viewModel.hasLoadedAudio {
                    // Recent files view
                    if viewModel.storedAudioFiles.isEmpty {
                        Button("Add Audio File") {
                            if let url = URL(string: "shareddocuments://") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .font(.title2)
                    } else {
                        VStack {
                            HStack {
                                Text("Recent Audio Files")
                                    .font(.headline)
                                Spacer()
                                Button("Add New") {
                                    if let url = URL(string: "shareddocuments://") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.horizontal)
                            
                            List {
                                ForEach(viewModel.storedAudioFiles.sorted(by: { $0.dateAdded > $1.dateAdded })) { storedFile in
                                    Button(action: {
                                        print("Tapped on stored file: \(storedFile.fileName)")
                                        viewModel.loadStoredAudio(storedFile)
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(storedFile.displayName)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                Text("Added: \(storedFile.formattedDate)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text(storedFile.formattedDuration)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            viewModel.deleteStoredFile(storedFile)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                } else if viewModel.hasLoadedAudio {
                    VStack(spacing: 20) {
                        // Audio filename
                        Text(viewModel.currentFileName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Playback controls
                        HStack(spacing: 15) {
                            Button(action: { viewModel.goToBeginning() }) {
                                Image(systemName: "backward.end.fill")
                            }
                            
                            Button(action: { viewModel.goBackward(by: 3) }) {
                                ZStack {
                                    Image(systemName: "gobackward")
                                    Text("3")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .offset(x: 0.3, y: 1)
                                }
                            }
                            
                            Button(action: { viewModel.togglePlayback() }) {
                                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            }
                            
                            Button(action: { viewModel.goForward(by: 15) }) {
                                ZStack {
                                    Image(systemName: "goforward")
                                    Text("15")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .offset(x: 0, y: 1)
                                }
                            }
                        }
                        .font(.title2)
                        .buttonStyle(PlainButtonStyle())
                        
                        // Current playback time display
                        HStack(spacing: 12) {
                            Text(timeString(from: viewModel.currentTime))
                                .font(.title3)
                                .monospacedDigit()
                                .foregroundColor(.primary)
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background track
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 2)
                                    
                                    // Progress track
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.6))
                                        .frame(width: geometry.size.width * viewModel.progress, height: 2)
                                    
                                    // Playback indicator (black vertical line)
                                    Rectangle()
                                        .fill(Color.black)
                                        .frame(width: 2, height: 12)
                                        .offset(x: geometry.size.width * viewModel.progress - 1)
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
                            .frame(height: 12)
                            
                            Text(timeString(from: viewModel.duration))
                                .font(.title3)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20) // Indent to match notes section
                        .padding(.top, -10)
                        
                        // Annotation buttons
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(AnnotationType.allCases, id: \.self) { type in
                                Button {
                                    if type == .custom {
                                        showingCustomAnnotation = true
                                    } else if type == .tooLoud || type == .tooQuiet {
                                        selectedAnnotationType = type
                                        showingInstrumentPicker = true
                                    } else {
                                        viewModel.addAnnotation(type)
                                    }
                                } label: {
                                    Text(type.rawValue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
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
                            }
                            Button("Add") {
                                viewModel.addAnnotation(.custom, customText: customAnnotationText)
                                customAnnotationText = ""
                            }
                        } message: {
                            Text("Enter a custom note for this timestamp")
                        }
                        
                        // Annotations list
                        List {
                            ForEach(viewModel.annotations.sorted(by: { $0.timestamp < $1.timestamp })) { annotation in
                                HStack {
                                    Text(timeString(from: annotation.timestamp))
                                        .monospacedDigit()
                                    Spacer()
                                    if annotation.type == .custom, let customText = annotation.customText {
                                        Text("Custom: \(customText)")
                                    } else if let customText = annotation.customText {
                                        Text("\(annotation.type.rawValue): \(customText)")
                                    } else {
                                        Text(annotation.type.rawValue)
                                    }
                                }
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
                }
            }

            Spacer(minLength: 0)

            if shouldShowBanner {
                Divider()

                BannerAdView(adUnitID: AdMobIdentifiers.bannerAdUnitID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .padding(.vertical, 4)
            }
        }
        .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    MixNotesTitleView()
                }
                
                if viewModel.hasLoadedAudio {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            viewModel.reset()
                        } label: {
                            Image(systemName: "chevron.backward")
                            Text("Recents")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Export") {
                            showingShareSheet = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [viewModel.exportAnnotations()])
            }
        }
    }

    private var shouldShowBanner: Bool {
        if viewModel.isLoadingFromBrowse {
            return false
        }

        if viewModel.hasLoadedAudio {
            return true
        }

        return !viewModel.storedAudioFiles.isEmpty
    }

    private func timeString(from timeInterval: TimeInterval) -> String {
        let time = abs(timeInterval)
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let sign = timeInterval < 0 ? "-" : ""
        return String(format: "%@%02d:%02d", sign, minutes, seconds)
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
}
