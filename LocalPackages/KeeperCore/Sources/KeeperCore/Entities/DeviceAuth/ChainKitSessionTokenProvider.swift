import ChainKit
import Foundation
import TKLogging

/// Hands ChainKit the device JWT for the requests it authenticates as the wallet's user — the node
/// manifest and, since the nodes started checking it themselves, the node calls too.
///
/// `getAccessToken` may be asked concurrently, so the renewal behind it is collapsed into a single
/// round trip by `DeviceAuthService`. A session that cannot be established yields `nil`, which
/// ChainKit sends unauthenticated and still gets a manifest from — a thrown error would instead
/// leave the node provider on the endpoints it already had.
final class ChainKitSessionTokenProvider: NSObject, ModuleSessionTokenProvider, @unchecked Sendable {
    private let deviceAuth: DeviceAuthProviding

    init(deviceAuth: DeviceAuthProviding) {
        self.deviceAuth = deviceAuth
    }

    func getAccessToken() async -> String? {
        await token { () async throws(DeviceAuthError) in try await self.deviceAuth.session() }
    }

    /// ChainKit calls this once per rejected token, but our own triggers renew the session too. The
    /// ladder rotates the refresh token, so repeating it for a token that is already replaced would
    /// spend the rotated one and come back as `refresh_reused`; `recoverSession` hands back the
    /// newer session in that case instead of starting a second renewal.
    func refreshToken(expiredToken: String) async -> String? {
        await token { () async throws(DeviceAuthError) in
            try await self.deviceAuth.recoverSession(invalidating: expiredToken)
        }
    }
}

private extension ChainKitSessionTokenProvider {
    func token(_ session: () async throws(DeviceAuthError) -> DeviceAuthSession) async -> String? {
        do {
            return try await session().accessToken
        } catch {
            if case .cancelled = error {
                return nil
            }
            Log.w("🪵 ChainKit: no device session, request goes out unauthenticated", error: error)
            return nil
        }
    }
}
