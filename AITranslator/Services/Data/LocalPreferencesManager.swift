import AITranslatorCore
import Foundation
import Observation

/// Persists `LocalAppPreferences` in `UserDefaults` with `@Observable` reactivity (Section 6.2).
@MainActor
@Observable
public final class LocalPreferencesManager {
    private static let prefsKey = "ai_translator_local_prefs_v1"
    private let defaults: UserDefaults

    public var preferences: LocalAppPreferences {
        didSet {
            save(preferences)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.prefsKey),
           let decoded = try? JSONDecoder().decode(LocalAppPreferences.self, from: data) {
            self.preferences = decoded
        } else {
            self.preferences = LocalAppPreferences()
        }
    }

    private func save(_ prefs: LocalAppPreferences) {
        if let data = try? JSONEncoder().encode(prefs) {
            defaults.set(data, forKey: Self.prefsKey)
        }
    }

    public func resetAll() {
        defaults.removeObject(forKey: Self.prefsKey)
        preferences = LocalAppPreferences()
    }
}
