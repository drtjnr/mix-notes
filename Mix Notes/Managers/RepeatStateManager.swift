import Foundation
import Combine

/// Manages the shared repeat state across all playback modes
final class RepeatStateManager: ObservableObject {
    static let shared = RepeatStateManager()

    private let userDefaultsKey = "isRepeating"

    @Published var isRepeating: Bool {
        didSet {
            UserDefaults.standard.set(isRepeating, forKey: userDefaultsKey)
        }
    }

    private init() {
        self.isRepeating = UserDefaults.standard.bool(forKey: userDefaultsKey)
    }
}
