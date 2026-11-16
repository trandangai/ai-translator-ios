@preconcurrency import FirebaseRemoteConfig
import Foundation
import Observation

/// Firebase Remote Config listener for budget kill switch (Section 6.3).
@MainActor
@Observable
public final class RemoteInterpreterConfig {
    public private(set) var isKillSwitchActive: Bool = false

    public init() {
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 60
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(["kill_switch_active": false as NSObject])
    }

    public func fetchAndActivate() async {
        do {
            isKillSwitchActive = try await Self.fetchKillSwitchValue()
        } catch {
            // Keep existing default/cached value
        }
    }

    private nonisolated static func fetchKillSwitchValue() async throws -> Bool {
        let remoteConfig = RemoteConfig.remoteConfig()
        _ = try await remoteConfig.fetchAndActivate()
        return remoteConfig.configValue(forKey: "kill_switch_active").boolValue
    }
}
