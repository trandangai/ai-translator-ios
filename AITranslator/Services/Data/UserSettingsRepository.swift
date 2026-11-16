import AITranslatorCore
import FirebaseFirestore
import Foundation
import Observation

/// Cloud Firestore `/users/{uid}` and `/users/{uid}/daily_quotas/{dateKey}` repository (Section 6.1).
@MainActor
@Observable
public final class UserSettingsRepository {
    public private(set) var profile: UserSettingsProfile?
    public private(set) var todayQuota: DailyUsageQuota = DailyUsageQuota()

    private let db = Firestore.firestore()

    public init() {}

    public func loadOrCreateUser(uid: String, defaults: LocalAppPreferences) async {
        let userRef = db.collection("users").document(uid)
        do {
            let snap = try await userRef.getDocument()
            if snap.exists, let data = snap.data() {
                self.profile = decodeProfile(uid: uid, data: data)
            } else {
                let newProfile = UserSettingsProfile(
                    userId: uid,
                    preferredPairId: defaults.preferredPairId,
                    interactionMode: defaults.interactionMode.rawValue,
                    subtitlesEnabled: defaults.subtitlesEnabled,
                    echoGatingTailMs: defaults.echoGatingTailMs,
                    vadSilenceMs: defaults.vadSilenceMs,
                    vadSensitivityPct: defaults.vadSensitivityPct,
                    volumeBoostDb: defaults.volumeBoostDb
                )
                try await userRef.setData([
                    "userId": newProfile.userId,
                    "preferredPairId": newProfile.preferredPairId,
                    "interactionMode": newProfile.interactionMode,
                    "subtitlesEnabled": newProfile.subtitlesEnabled,
                    "echoGatingTailMs": newProfile.echoGatingTailMs,
                    "vadSilenceMs": newProfile.vadSilenceMs,
                    "vadSensitivityPct": newProfile.vadSensitivityPct,
                    "volumeBoostDb": newProfile.volumeBoostDb,
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                self.profile = newProfile
            }
            await loadOrCreateTodayQuota(uid: uid, dailyCapSeconds: defaults.dailyCapSeconds)
        } catch {
            // Offline or permission fallback handled gracefully
        }
    }

    public func syncSettings(uid: String, prefs: LocalAppPreferences) async {
        let userRef = db.collection("users").document(uid)
        do {
            try await userRef.updateData([
                "preferredPairId": prefs.preferredPairId,
                "interactionMode": prefs.interactionMode.rawValue,
                "subtitlesEnabled": prefs.subtitlesEnabled,
                "echoGatingTailMs": prefs.echoGatingTailMs,
                "vadSilenceMs": prefs.vadSilenceMs,
                "vadSensitivityPct": prefs.vadSensitivityPct,
                "volumeBoostDb": prefs.volumeBoostDb,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch {}
    }

    public func loadOrCreateTodayQuota(uid: String, dailyCapSeconds: Int) async {
        let dateKey = DailyUsageQuota.utcDateKey()
        let quotaRef = db.collection("users").document(uid).collection("daily_quotas").document(dateKey)
        do {
            let snap = try await quotaRef.getDocument()
            if snap.exists, let data = snap.data() {
                self.todayQuota = DailyUsageQuota(
                    audioSecondsUsed: data["audioSecondsUsed"] as? Int ?? 0,
                    sessionsCount: data["sessionsCount"] as? Int ?? 0,
                    transcribeCount: data["transcribeCount"] as? Int ?? 0,
                    dailyCapSeconds: data["dailyCapSeconds"] as? Int ?? dailyCapSeconds
                )
            } else {
                let initial = DailyUsageQuota(dailyCapSeconds: dailyCapSeconds)
                try await quotaRef.setData([
                    "audioSecondsUsed": 0,
                    "sessionsCount": 0,
                    "transcribeCount": 0,
                    "dailyCapSeconds": initial.dailyCapSeconds,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                self.todayQuota = initial
            }
        } catch {}
    }

    public func incrementUsage(
        uid: String,
        audioSecondsDelta: Int = 0,
        sessionsDelta: Int = 0,
        transcribeDelta: Int = 0
    ) async {
        let dateKey = DailyUsageQuota.utcDateKey()
        let quotaRef = db.collection("users").document(uid).collection("daily_quotas").document(dateKey)

        todayQuota.audioSecondsUsed = min(86400, todayQuota.audioSecondsUsed + max(0, audioSecondsDelta))
        todayQuota.sessionsCount = min(10000, todayQuota.sessionsCount + max(0, sessionsDelta))
        todayQuota.transcribeCount = min(50000, todayQuota.transcribeCount + max(0, transcribeDelta))

        var updates: [String: Any] = ["updatedAt": FieldValue.serverTimestamp()]
        if audioSecondsDelta > 0 {
            updates["audioSecondsUsed"] = FieldValue.increment(Int64(audioSecondsDelta))
        }
        if sessionsDelta > 0 {
            updates["sessionsCount"] = FieldValue.increment(Int64(sessionsDelta))
        }
        if transcribeDelta > 0 {
            updates["transcribeCount"] = FieldValue.increment(Int64(transcribeDelta))
        }

        try? await quotaRef.setData(updates, merge: true)
    }

    private func decodeProfile(uid: String, data: [String: Any]) -> UserSettingsProfile {
        UserSettingsProfile(
            userId: data["userId"] as? String ?? uid,
            preferredPairId: data["preferredPairId"] as? String ?? "vi_en",
            interactionMode: data["interactionMode"] as? String ?? "AUTO",
            subtitlesEnabled: data["subtitlesEnabled"] as? Bool ?? false,
            echoGatingTailMs: data["echoGatingTailMs"] as? Int ?? 320,
            vadSilenceMs: data["vadSilenceMs"] as? Int ?? 400,
            vadSensitivityPct: data["vadSensitivityPct"] as? Int ?? 65,
            volumeBoostDb: data["volumeBoostDb"] as? Int ?? 3
        )
    }
}
