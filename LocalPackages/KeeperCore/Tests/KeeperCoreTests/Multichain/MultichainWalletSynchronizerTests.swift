import BigInt
import Foundation
@testable import KeeperCore
import XCTest

final class MultichainWalletSynchronizerTests: XCTestCase {
    func test_sync_marksTheWalletBoundWhenTheBackendReturnsItsWalletId() async throws {
        let context = Context()
        context.api.registerResults = [[.init(index: 0, walletId: Context.walletId, error: nil)]]

        try await context.synchronizer.sync(mnemonic: "words", state: context.state)

        XCTAssertEqual(context.chainKit.signedBatches.map(\.deviceId), ["device-1"])
        XCTAssertEqual(context.api.registeredChallenges, ["challenge-1"])
    }

    func test_sync_failsWhenSuccessfulResultCarriesNoWalletId() async {
        let context = Context()
        // `wallet_id` is optional in the schema, so an `ok` without it is representable.
        context.api.registerResults = [[.init(index: 0, walletId: nil, error: nil)]]

        do {
            try await context.synchronizer.sync(mnemonic: "words", state: context.state)
            XCTFail("expected a missing wallet id to fail the sync")
        } catch {
            XCTAssertTrue(context.errorMessage(error).contains("walletId=nil"))
        }
    }

    func test_sync_failsWhenTheBackendBindsAnotherWallet() async {
        let context = Context()
        context.api.registerResults = [[.init(index: 0, walletId: "another-wallet", error: nil)]]

        do {
            try await context.synchronizer.sync(mnemonic: "words", state: context.state)
            XCTFail("expected a mismatched wallet id to fail the sync")
        } catch {
            XCTAssertTrue(context.errorMessage(error).contains("another-wallet"))
        }
    }

    func test_sync_resignsTheBatchWhenRecoveryRotatesTheDevice() async throws {
        let context = Context()
        context.deviceAuth.recoveredDeviceId = "device-2"
        context.api.registerErrors = [.unauthorized(message: "device_revoked")]
        context.api.registerResults = [[.init(index: 0, walletId: Context.walletId, error: nil)]]

        try await context.synchronizer.sync(mnemonic: "words", state: context.state)

        // The proof is bound to the device id and the challenge is single-use, so the replay is
        // re-signed for the new device instead of repeating the rejected body.
        XCTAssertEqual(context.chainKit.signedBatches.map(\.deviceId), ["device-1", "device-2"])
        XCTAssertEqual(context.api.registeredChallenges, ["challenge-1", "challenge-2"])
        XCTAssertEqual(context.api.registeredProofs, ["proof-device-1", "proof-device-2"])
    }

    func test_sync_replaysTheSameBatchWhenTheDeviceIsUnchanged() async throws {
        let context = Context()
        context.api.registerErrors = [.unauthorized(message: "token_expired")]
        context.api.registerResults = [[.init(index: 0, walletId: Context.walletId, error: nil)]]

        try await context.synchronizer.sync(mnemonic: "words", state: context.state)

        XCTAssertEqual(context.chainKit.signedBatches.count, 1)
        XCTAssertEqual(context.api.registeredChallenges, ["challenge-1", "challenge-1"])
    }
}

private final class Context {
    static let walletId = String(repeating: "a", count: 64)

    let vault = InMemoryKeychainVault()
    let api = MultichainAuthClientAPISpy()
    let chainKit = ChainKitServiceFake()
    let deviceAuth = DeviceAuthFake()
    private let fallbackSuiteName = "MultichainWalletSynchronizerTests.\(UUID().uuidString)"
    private lazy var fallbackDefaults = UserDefaults(suiteName: fallbackSuiteName)!

    let state = MultichainWalletState(
        walletId: Context.walletId,
        addresses: [MultichainWalletAddress(chain: .ton, address: "ton-address")]
    )

    lazy var synchronizer: MultichainWalletSynchronizer = MultichainWalletSynchronizerImplementation(
        chainKitService: chainKit,
        multichainService: MultichainServiceFake(
            walletChallengeScript: .init(["challenge-1", "challenge-2"])
        ),
        authService: MultichainAuthServiceImplementation(
            clientAPI: api,
            deviceAuth: deviceAuth,
            pendingUnregisterStore: MultichainPendingUnregisterStore(
                keychainVault: vault,
                fallbackDefaults: fallbackDefaults
            )
        )
    )

    deinit {
        fallbackDefaults.removePersistentDomain(forName: fallbackSuiteName)
    }

    func errorMessage(_ error: MultichainServiceError) -> String {
        guard case let .apiError(message) = error else {
            return ""
        }
        return message ?? ""
    }
}

private final class DeviceAuthFake: DeviceAuthProviding, @unchecked Sendable {
    var recoveredDeviceId = "device-1"

    func session() async throws(DeviceAuthError) -> DeviceAuthSession {
        DeviceAuthSession(deviceId: "device-1", accessToken: "jwt-1")
    }

    func recoverSession(invalidating _: String) async throws(DeviceAuthError) -> DeviceAuthSession {
        DeviceAuthSession(deviceId: recoveredDeviceId, accessToken: "jwt-2")
    }

    func isDeviceKnown() async -> Bool {
        true
    }
}

private final class MultichainAuthClientAPISpy: MultichainAuthClientAPI, @unchecked Sendable {
    /// Consumed in order; an exhausted list stops failing.
    var registerErrors = [MultichainClientAPIError]()
    /// Consumed in order; the last batch keeps repeating.
    var registerResults = [[MultichainWalletRegisterResult]]()
    private(set) var registeredChallenges = [String]()
    private(set) var registeredProofs = [String]()

    func registerWallets(
        challenge: String,
        wallets: [MultichainWalletRegisterItem],
        deviceJWT _: String
    ) async throws(MultichainClientAPIError) -> [MultichainWalletRegisterResult] {
        registeredChallenges.append(challenge)
        registeredProofs.append(contentsOf: wallets.map(\.walletProof))
        if !registerErrors.isEmpty {
            throw registerErrors.removeFirst()
        }
        return registerResults.count > 1 ? registerResults.removeFirst() : (registerResults.first ?? [])
    }

    func getDeviceChallenge() async throws(MultichainClientAPIError) -> MultichainWalletChallenge {
        MultichainWalletChallenge(challenge: "device-challenge", expiresAt: Date())
    }

    func registerDevice(
        devicePublicKey _: String,
        deviceProof _: String,
        challenge _: String,
        platform _: String,
        appId _: Int64,
        clientVersion _: String
    ) async throws(MultichainClientAPIError) -> DeviceTokenPair {
        DeviceTokenPair(deviceId: "device-1", accessToken: "jwt-1", refreshToken: "refresh-1", expiresIn: 900)
    }

    func refreshDevice(
        deviceId: String,
        refreshToken _: String,
        deviceProof _: String
    ) async throws(MultichainClientAPIError) -> DeviceTokenPair {
        DeviceTokenPair(deviceId: deviceId, accessToken: "jwt-2", refreshToken: "refresh-2", expiresIn: 900)
    }

    func getDeviceBindings(
        walletIds _: [String],
        deviceJWT _: String
    ) async throws(MultichainClientAPIError) -> DeviceBindings {
        DeviceBindings(known: [], unknown: [], extra: [])
    }

    func unregisterWallets(
        walletIds: [String],
        deviceJWT _: String
    ) async throws(MultichainClientAPIError) -> [String] {
        walletIds
    }

    func subscribeWalletPush(
        pushToken _: String,
        locale _: String?,
        walletIds _: [String],
        deviceJWT _: String
    ) async throws(MultichainClientAPIError) {}

    func unsubscribeWalletPush(deviceJWT _: String) async throws(MultichainClientAPIError) {}
}

private final class ChainKitServiceFake: ChainKitService, @unchecked Sendable {
    private(set) var signedBatches = [(deviceId: String, challenge: String)]()

    func makeWalletRegisterItem(
        mnemonic _: String,
        deviceId: String,
        challenge: String,
        state: MultichainWalletState
    ) throws -> MultichainWalletRegisterItem {
        signedBatches.append((deviceId, challenge))
        return MultichainWalletRegisterItem(
            walletId: state.walletId,
            walletProof: "proof-\(deviceId)",
            accounts: state.addresses
        )
    }

    func walletAppPrivateKey(mnemonic: String) throws -> Data {
        Data("key-\(mnemonic)".utf8)
    }

    func walletAuthToken(appPrivateKey _: Data, accessToken _: String) -> String {
        fatalError("unused")
    }

    func isTransferSupported(asset _: MultichainAsset) -> Bool {
        fatalError("unused")
    }

    func tronPrivateKey(mnemonic _: String) throws -> Data {
        fatalError("unused")
    }

    func makeBatterySendProof(
        mnemonic _: String,
        walletId _: String,
        boc _: String
    ) throws -> String {
        fatalError("unused")
    }

    func emulateTransaction(
        wallet _: Wallet,
        recipient _: String,
        asset _: MultichainAsset,
        amount _: BigUInt,
        comment _: String?,
        isMaxAmount _: Bool
    ) async throws(MultichainTransactionEmulationFailure) -> MultichainTransactionEmulationResult {
        fatalError("unused")
    }

    func sendMultichainTransfer(
        passcodeProvider _: @escaping () async -> String?,
        wallet _: Wallet,
        recipient _: String,
        asset _: MultichainAsset,
        amount _: BigUInt,
        comment _: String?,
        isMaxAmount _: Bool
    ) async throws(MultichainTransactionFailure) -> [String] {
        fatalError("unused")
    }

    func makeWalletState(mnemonic _: String) throws -> MultichainWalletState {
        fatalError("unused")
    }

    func addresses(mnemonic _: String) -> [MultichainWalletAddress] {
        fatalError("unused")
    }

    func makeMnemonic() throws(MultichainMakeMnemonicFailure) -> [String] {
        fatalError("unused")
    }
}
