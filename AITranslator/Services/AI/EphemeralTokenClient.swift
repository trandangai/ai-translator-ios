import FirebaseFunctions
import Foundation

public struct EphemeralLiveToken: Sendable {
    public let token: String
    public let expiresInSeconds: Int
}

/// Calls `mintEphemeralLiveToken` in `asia-northeast1` with App Check enforced (Section 6.3).
public final class EphemeralTokenClient: Sendable {
    private let functions = Functions.functions(region: "asia-northeast1")

    public init() {}

    public func mintToken() async throws -> EphemeralLiveToken {
        let result = try await functions.httpsCallable("mintEphemeralLiveToken").call()
        guard let dict = result.data as? [String: Any],
              let token = dict["token"] as? String else {
            throw NSError(
                domain: "EphemeralTokenClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid ephemeral token payload"]
            )
        }
        let expires = dict["expiresInSeconds"] as? Int ?? 300
        return EphemeralLiveToken(token: token, expiresInSeconds: expires)
    }
}
