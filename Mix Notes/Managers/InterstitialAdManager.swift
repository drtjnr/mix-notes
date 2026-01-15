//
//  InterstitialAdManager.swift
//  Mix Notes
//
//  Created by David Thomas on 1/15/26.
//

import Foundation
import GoogleMobileAds
import UIKit

/// Manages App Open ad loading and presentation for cold start display
final class InterstitialAdManager: NSObject, ObservableObject {
    static let shared = InterstitialAdManager()

    // App Open Ad Unit ID
    // Test ID: "ca-app-pub-3940256099942544/5575463023"
    // Production: create new App Open ad unit in AdMob console
    private let adUnitID = "ca-app-pub-2186858726503482/3445377178"

    private var appOpenAd: GADAppOpenAd?
    @Published private(set) var isAdReady = false
    @Published private(set) var hasShownAdThisSession = false

    private override init() {
        super.init()
    }

    /// Call this early (in AppDelegate) to preload the ad
    func preloadAd() {
        print("AppOpenAdManager: preloadAd() called")
        guard appOpenAd == nil && !hasShownAdThisSession else {
            print("AppOpenAdManager: Skipping preload - ad already exists or already shown")
            return
        }

        Task {
            await loadAd()
        }
    }

    private func loadAd() async {
        print("AppOpenAdManager: Starting to load ad...")
        do {
            appOpenAd = try await GADAppOpenAd.load(
                withAdUnitID: adUnitID,
                request: GADRequest()
            )
            appOpenAd?.fullScreenContentDelegate = self
            print("AppOpenAdManager: Ad loaded successfully!")
            await MainActor.run {
                isAdReady = true
            }
        } catch {
            print("AppOpenAdManager: Failed to load ad - \(error.localizedDescription)")
            await MainActor.run {
                isAdReady = false
            }
        }
    }

    /// Shows the app open ad if ready. Returns true if ad was shown.
    @MainActor
    func showAdIfReady() -> Bool {
        print("AppOpenAdManager: showAdIfReady() called")
        print("AppOpenAdManager: appOpenAd is \(appOpenAd == nil ? "nil" : "loaded")")
        print("AppOpenAdManager: hasShownAdThisSession = \(hasShownAdThisSession)")
        print("AppOpenAdManager: rootViewController is \(rootViewController() == nil ? "nil" : "available")")

        guard let ad = appOpenAd,
              !hasShownAdThisSession,
              let rootViewController = rootViewController() else {
            print("AppOpenAdManager: Cannot show ad - conditions not met")
            return false
        }

        print("AppOpenAdManager: Presenting ad now...")
        ad.present(fromRootViewController: rootViewController)
        hasShownAdThisSession = true
        return true
    }

    /// Check if ad can be shown (ready and not yet shown this session)
    var canShowAd: Bool {
        appOpenAd != nil && !hasShownAdThisSession
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    }
}

// MARK: - GADFullScreenContentDelegate

extension InterstitialAdManager: GADFullScreenContentDelegate {
    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        print("AppOpenAdManager: Ad recorded impression")
    }

    func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
        print("AppOpenAdManager: Ad recorded click")
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("AppOpenAdManager: Failed to present - \(error.localizedDescription)")
        appOpenAd = nil
        isAdReady = false
    }

    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("AppOpenAdManager: Will present full screen content")
    }

    func adWillDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("AppOpenAdManager: Will dismiss full screen content")
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("AppOpenAdManager: Did dismiss full screen content")
        appOpenAd = nil
        isAdReady = false
    }
}
