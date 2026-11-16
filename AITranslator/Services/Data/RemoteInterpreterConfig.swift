import FirebaseRemoteConfig
import Foundation
import Observation

/// Firebase Remote Config listener for budget kill switch (Section 6.3).
@MainActor
@Observable
public final class RemoteInterpreterConfig {
    public private(set) var isKillSwitchActive: Bool = false
    private let remoteConfig = RemoteConfig.remoteConfig()

    public init() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 60
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(["kill_switch_active": false as NSObject])
    }

    public func fetchAndActivate() async {
        do {
            _ = try await remoteConfig.fetchAndActivate()
            isKillSwitchActive = remoteConfig.configValue(forKey: "kill_switch_active").boolValue
        } catch {
            // Keep existing default/cached value
        }
    }
}
