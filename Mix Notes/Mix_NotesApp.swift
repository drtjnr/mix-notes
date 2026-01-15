//
//  Mix_NotesApp.swift
//  Mix Notes
//
//  Created by David Thomas on 1/4/25.
//

import SwiftUI
import UIKit
import GoogleMobileAds
import Combine

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        GADMobileAds.sharedInstance().start { _ in
            // SDK initialized - begin preloading interstitial ad
            InterstitialAdManager.shared.preloadAd()
        }
        return true
    }
}

@main
struct Mix_NotesApp: App {
    @StateObject private var viewModel = AudioAnnotationViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isLoading = true
    @State private var isColdStart = true
    @State private var adCancellable: AnyCancellable?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(viewModel: viewModel)
                    .onOpenURL { url in
                        // Handle incoming URLs (from Messages, Files app, etc.)
                        handleIncomingURL(url)
                    }
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    LaunchScreenView()
                        .transition(.opacity)
                }
            }
            .onAppear {
                // Show launch screen for a brief moment
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isLoading = false
                    }
                    // Enable interstitial display after launch screen fades
                    if isColdStart {
                        setupInterstitialObserver()
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Mark as not cold start once app goes to background
                if newPhase == .background {
                    isColdStart = false
                    adCancellable?.cancel()
                    adCancellable = nil
                }
            }
        }
    }

    private func setupInterstitialObserver() {
        // If ad is already ready, show it immediately
        if InterstitialAdManager.shared.showAdIfReady() {
            return
        }

        // Otherwise, subscribe to isAdReady and show when it becomes true
        adCancellable = InterstitialAdManager.shared.$isAdReady
            .receive(on: DispatchQueue.main)
            .filter { $0 == true }
            .first()
            .sink { _ in
                _ = InterstitialAdManager.shared.showAdIfReady()
                adCancellable = nil
            }

        // Timeout after 5 seconds - don't keep user waiting too long
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            adCancellable?.cancel()
            adCancellable = nil
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Check if it's an audio file by examining the file extension
        let audioExtensions = ["mp3", "wav", "aiff", "aif", "m4a", "aac", "caf", "mp4"]
        let fileExtension = url.pathExtension.lowercased()
        
        guard audioExtensions.contains(fileExtension) else {
            print("File is not a supported audio format: \(fileExtension)")
            return
        }
        
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access the selected file")
            return
        }
        
        // Load the audio file
        viewModel.loadAudio(from: url)
        url.stopAccessingSecurityScopedResource()
    }
}
