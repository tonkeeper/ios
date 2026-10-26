import Foundation

/// Credentials the battery accepts for one wallet. Exactly one identity travels per request: a
/// wallet with a backend wallet id authenticates by that id and the device session, every other
/// wallet by its ton-proof. The backend keeps a separate account per identity, so sending both
/// would let reads and sends land on different accounts.
struct BatteryAuthorization: Equatable {
    let tonProof: String?
    let walletId: String?
    let deviceAccessToken: String?
    /// Signed by the wallet's app key over `deviceAccessToken`, naming the one wallet this request
    /// may act on. Absent whenever the app key is not available, which the backend still accepts.
    let walletAuthToken: String?

    init(
        tonProof: String?,
        walletId: String?,
        deviceAccessToken: String?,
        walletAuthToken: String? = nil
    ) {
        self.tonProof = tonProof
        self.walletId = walletId
        self.deviceAccessToken = deviceAccessToken
        self.walletAuthToken = walletAuthToken
    }

    static let none = BatteryAuthorization(tonProof: nil, walletId: nil, deviceAccessToken: nil)

    var isEmpty: Bool {
        tonProof == nil && deviceAccessToken == nil
    }

    /// The headers the battery reads the credentials from. A missing credential sends no header,
    /// since an empty value would fail it.
    var httpHeaderFields: [(name: String, value: String)] {
        var fields = [(name: String, value: String)]()
        if let tonProof {
            fields.append((Self.tonConnectAuthHeader, tonProof))
        }
        if let walletId {
            fields.append((Self.walletIdHeader, walletId))
        }
        if let deviceAccessToken {
            fields.append((Self.authorizationHeader, "Bearer \(deviceAccessToken)"))
        }
        if let walletAuthToken {
            fields.append((Self.walletAuthorizationHeader, walletAuthToken))
        }
        return fields
    }

    static let tonConnectAuthHeader = "X-TonConnect-Auth"
    static let walletIdHeader = "X-Wallet-ID"
    static let authorizationHeader = "Authorization"
    static let walletAuthorizationHeader = "X-Wallet-Authorization"
}

enum BatteryAuthorizationError: Error, Equatable {
    case unavailable
}

final class BatteryAuthorizationService {
    private let tonProofTokenService: TonProofTokenService
    private let deviceAuth: DeviceAuthProviding
    private let walletAuthTokenProvider: WalletAuthTokenProviding

    init(
        tonProofTokenService: TonProofTokenService,
        deviceAuth: DeviceAuthProviding,
        walletAuthTokenProvider: WalletAuthTokenProviding
    ) {
        self.tonProofTokenService = tonProofTokenService
        self.deviceAuth = deviceAuth
        self.walletAuthTokenProvider = walletAuthTokenProvider
    }

    func authorization(for wallet: Wallet) async throws -> BatteryAuthorization {
        if let walletId = walletId(for: wallet) {
            guard let deviceAccessToken = await deviceAccessToken(for: wallet) else {
                throw BatteryAuthorizationError.unavailable
            }
            return await BatteryAuthorization(
                tonProof: nil,
                walletId: walletId,
                deviceAccessToken: deviceAccessToken,
                walletAuthToken: walletAuthToken(walletId: walletId, deviceAccessToken: deviceAccessToken)
            )
        }
        guard let tonProof = tonProof(for: wallet) else {
            throw BatteryAuthorizationError.unavailable
        }
        return BatteryAuthorization(tonProof: tonProof, walletId: nil, deviceAccessToken: nil)
    }

    func withAuthorization<T>(
        for wallet: Wallet,
        operation: (BatteryAuthorization) async throws -> T
    ) async throws -> T {
        try await withAuthorization(
            await authorization(for: wallet),
            operation: operation
        )
    }

    /// For endpoints the backend also answers unauthenticated. Credentials still travel when the
    /// wallet has them, but a wallet that cannot build any must not lose the whole call — the Tron
    /// fee estimate is shared by the battery, TON and TRX methods, and only the first needs auth.
    func withOptionalAuthorization<T>(
        for wallet: Wallet,
        operation: (BatteryAuthorization) async throws -> T
    ) async throws -> T {
        try await withAuthorization(
            (try? await authorization(for: wallet)) ?? .none,
            operation: operation
        )
    }

    private func withAuthorization<T>(
        _ authorization: BatteryAuthorization,
        operation: (BatteryAuthorization) async throws -> T
    ) async throws -> T {
        do {
            return try await operation(authorization)
        } catch let error as BatteryAPI.ApiError {
            guard case let .badStatus(status, _) = error,
                  status == 401,
                  let expiredToken = authorization.deviceAccessToken
            else {
                throw error
            }

            let recovered = try await deviceAuth.recoverSession(invalidating: expiredToken)
            guard !recovered.accessToken.isEmpty else {
                throw BatteryAuthorizationError.unavailable
            }
            // The wallet auth token is signed over the device access token, so a recovered session
            // invalidates it too.
            return try await operation(
                BatteryAuthorization(
                    tonProof: authorization.tonProof,
                    walletId: authorization.walletId,
                    deviceAccessToken: recovered.accessToken,
                    walletAuthToken: await walletAuthToken(
                        walletId: authorization.walletId,
                        deviceAccessToken: recovered.accessToken
                    )
                )
            )
        }
    }
}

private extension BatteryAuthorizationService {
    func tonProof(for wallet: Wallet) -> String? {
        guard let tonProof = try? tonProofTokenService.getWalletToken(wallet),
              !tonProof.isEmpty
        else {
            return nil
        }
        return tonProof
    }

    func walletId(for wallet: Wallet) -> String? {
        guard let walletId = wallet.multichainWalletState?.walletId,
              !walletId.isEmpty
        else {
            return nil
        }
        return walletId
    }

    func walletAuthToken(walletId: String?, deviceAccessToken: String?) async -> String? {
        guard let walletId, let deviceAccessToken else {
            return nil
        }
        return await walletAuthTokenProvider.token(walletId: walletId, accessToken: deviceAccessToken)
    }

    /// Only a wallet the backend can identify needs a device session, so a legacy wallet never pays
    /// for one just to read its battery balance.
    func deviceAccessToken(for wallet: Wallet) async -> String? {
        guard walletId(for: wallet) != nil,
              let session = try? await deviceAuth.session(),
              !session.accessToken.isEmpty
        else {
            return nil
        }
        return session.accessToken
    }
}
