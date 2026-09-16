import TKLogging

public protocol MultichainWalletSynchronizer {
    /// Binds one wallet to the current device via `/api/v2/wallets/register`.
    func sync(
        mnemonic: String,
        state: MultichainWalletState
    ) async throws(MultichainServiceError)
}

struct MultichainWalletSynchronizerImplementation: MultichainWalletSynchronizer {
    private let chainKitService: ChainKitService
    private let multichainService: MultichainService
    private let authService: MultichainAuthService

    init(
        chainKitService: ChainKitService,
        multichainService: MultichainService,
        authService: MultichainAuthService
    ) {
        self.chainKitService = chainKitService
        self.multichainService = multichainService
        self.authService = authService
    }

    func sync(
        mnemonic: String,
        state: MultichainWalletState
    ) async throws(MultichainServiceError) {
        // The device id is bound into the proof and the challenge is single-use, so both are
        // produced per attempt: a session recovery that rotates the device re-enters here.
        let results = try await authService.registerWallets(walletId: state.walletId) { deviceId throws(MultichainServiceError) in
            let challenge = try await multichainService.getWalletChallenge().challenge
            do {
                let item = try chainKitService.makeWalletRegisterItem(
                    mnemonic: mnemonic,
                    deviceId: deviceId,
                    challenge: challenge,
                    state: state
                )
                return (challenge: challenge, wallets: [item])
            } catch {
                throw .apiError(
                    message: "failed to sign multichain wallet register request: \(error.logDescription)"
                )
            }
        }
        // One item in, exactly one result for index 0 out: anything else is a protocol error and
        // must not mark the wallet synced.
        guard results.count == 1, let result = results.first, result.index == 0 else {
            throw .apiError(
                message: "multichain wallet register returned \(results.count) results for 1 item"
            )
        }
        if let error = result.error {
            throw .apiError(message: "multichain wallet register failed: \(error)")
        }
        // `wallet_id` is only present on success, and a different one means the backend bound
        // something else; either way the local wallet must not be marked synced.
        guard result.walletId == state.walletId else {
            throw .apiError(
                message: "multichain wallet register bound walletId=\(result.walletId ?? "nil"), expected \(state.walletId)"
            )
        }
    }
}
