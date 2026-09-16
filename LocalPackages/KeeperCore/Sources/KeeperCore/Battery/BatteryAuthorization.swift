import Foundation

/// Credentials the battery accepts for one wallet. Both halves travel together when the wallet has
/// them: a BIP39 wallet has no ton-proof, a legacy one has no wallet id, and a wallet imported by
/// BIP39 into the TON-only flow has both — the backend takes whichever it currently authenticates.
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
        let walletId = walletId(for: wallet)
        let deviceAccessToken = await deviceAccessToken(for: wallet)
        let authorization = await BatteryAuthorization(
            tonProof: tonProof(for: wallet),
            walletId: walletId,
            deviceAccessToken: deviceAccessToken,
            walletAuthToken: walletAuthToken(walletId: walletId, deviceAccessToken: deviceAccessToken)
        )
        guard !authorization.isEmpty else {
            throw BatteryAuthorizationError.unavailable
        }
        return authorization
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
