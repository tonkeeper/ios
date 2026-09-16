import Foundation
import TKLogging

/// Credentials handed to the battery web page for one wallet. Every field is nonempty because the
/// page rejects partial authorization.
public struct BatteryWebAuthorization: Equatable, Sendable {
    public let walletId: String
    public let deviceToken: String
    public let walletToken: String

    public init(walletId: String, deviceToken: String, walletToken: String) {
        self.walletId = walletId
        self.deviceToken = deviceToken
        self.walletToken = walletToken
    }
}

public protocol BatteryWebAuthorizationService: Sendable {
    /// `expiredDeviceToken == nil` asks for the current device session; otherwise the session is
    /// recovered so that `expiredDeviceToken` is never handed back. Throws when any credential is
    /// unavailable.
    func authorization(for wallet: Wallet, expiredDeviceToken: String?) async throws -> BatteryWebAuthorization
}

final class BatteryWebAuthorizationServiceImplementation: BatteryWebAuthorizationService {
    private let deviceAuth: DeviceAuthProviding
    private let walletAuthTokenProvider: WalletAuthTokenProviding

    init(deviceAuth: DeviceAuthProviding, walletAuthTokenProvider: WalletAuthTokenProviding) {
        self.deviceAuth = deviceAuth
        self.walletAuthTokenProvider = walletAuthTokenProvider
    }

    func authorization(for wallet: Wallet, expiredDeviceToken: String?) async throws -> BatteryWebAuthorization {
        guard let walletId = wallet.multichainWalletState?.walletId, !walletId.isEmpty else {
            throw BatteryAuthorizationError.unavailable
        }
        let deviceToken = try await deviceToken(expiredDeviceToken: expiredDeviceToken)
        guard !deviceToken.isEmpty,
              let walletToken = await walletAuthTokenProvider.token(walletId: walletId, accessToken: deviceToken),
              !walletToken.isEmpty
        else {
            throw BatteryAuthorizationError.unavailable
        }

        Log.d("battery web auth: prepared", extraInfo: [
            "refresh": String(expiredDeviceToken != nil),
            "deviceTokenChanged": String(expiredDeviceToken != nil && deviceToken != expiredDeviceToken),
        ])

        return BatteryWebAuthorization(
            walletId: walletId,
            deviceToken: deviceToken,
            walletToken: walletToken
        )
    }
}

private extension BatteryWebAuthorizationServiceImplementation {
    func deviceToken(expiredDeviceToken: String?) async throws -> String {
        if let expiredDeviceToken {
            return try await deviceAuth.recoverSession(invalidating: expiredDeviceToken).accessToken
        }
        return try await deviceAuth.session().accessToken
    }
}
