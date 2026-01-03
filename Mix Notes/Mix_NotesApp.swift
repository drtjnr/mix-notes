//
//  Mix_NotesApp.swift
//  Mix Notes
//
//  Created by David Thomas on 1/4/25.
//

import SwiftUI
import UIKit
import GoogleMobileAds

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        return true
    }
}

@main
struct Mix_NotesApp: App {
    @StateObject private var viewModel = AudioAnnotationViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isLoading = true

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
                }
            }
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
