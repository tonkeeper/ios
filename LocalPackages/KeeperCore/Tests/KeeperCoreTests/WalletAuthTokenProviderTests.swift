import BigInt
import Foundation
@testable import KeeperCore
import Security
import TKKeychain
import XCTest

final class WalletAuthTokenProviderTests: XCTestCase {
    /// The provider is owned above `MultichainAssembly` so the battery can read it without closing a
    /// cycle over `ServicesAssembly`. That only holds while `ChainKitService` is resolved on use:
    /// resolving it at init would reintroduce the recursion, which no type check catches.
    func test_chainKitService_isNotResolvedUntilFirstUse() async {
        let chainKit = ChainKitWalletAuthFake()
        var resolveCount = 0

        let provider = WalletAuthTokenProvider(
            chainKitService: {
                resolveCount += 1
                return chainKit
            },
            store: WalletAuthKeychainStore(keychainVault: InMemoryKeychainVault())
        )
        XCTAssertEqual(resolveCount, 0)

        await provider.warm(walletId: "wallet-1", mnemonic: "phrase")
        XCTAssertEqual(resolveCount, 1)
    }

    func test_withoutWarmKey_yieldsNoToken() async {
        let chainKit = ChainKitWalletAuthFake()
        let provider = makeProvider(chainKit: chainKit)

        let token = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")

        XCTAssertNil(token)
        XCTAssertEqual(chainKit.signedAccessTokens, [])
        let hasKey = await provider.hasPersistentAppKey(walletId: "wallet-1")
        XCTAssertFalse(hasKey)
    }

    func test_warmedKey_mintsAndCachesToken() async {
        let chainKit = ChainKitWalletAuthFake()
        let provider = makeProvider(chainKit: chainKit)
        await provider.warm(walletId: "wallet-1", mnemonic: "phrase")

        let first = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        let second = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")

        XCTAssertEqual(first, "signed(key-phrase,jwt-1)")
        XCTAssertEqual(second, first)
        // Cached: the second read must not sign again.
        XCTAssertEqual(chainKit.signedAccessTokens, ["jwt-1"])
        let hasKey = await provider.hasPersistentAppKey(walletId: "wallet-1")
        XCTAssertTrue(hasKey)
    }

    /// A token is only valid for the access token it signs, so a rotation has to produce a new one
    /// rather than serve the one minted for the previous session.
    func test_rotatedAccessToken_remintsAndDropsThePreviousToken() async {
        let chainKit = ChainKitWalletAuthFake()
        let provider = makeProvider(chainKit: chainKit)
        await provider.warm(walletId: "wallet-1", mnemonic: "phrase")
        _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")

        let rotated = await provider.token(walletId: "wallet-1", accessToken: "jwt-2")
        // Re-asking for the retired token mints again instead of hitting a stale cache entry.
        _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")

        XCTAssertEqual(rotated, "signed(key-phrase,jwt-2)")
        XCTAssertEqual(chainKit.signedAccessTokens, ["jwt-1", "jwt-2", "jwt-1"])
    }

    func test_separateWallets_getSeparateTokens() async {
        let chainKit = ChainKitWalletAuthFake()
        let provider = makeProvider(chainKit: chainKit)
        await provider.warm(walletId: "wallet-1", mnemonic: "one")
        await provider.warm(walletId: "wallet-2", mnemonic: "two")

        let first = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        let second = await provider.token(walletId: "wallet-2", accessToken: "jwt-1")

        XCTAssertEqual(first, "signed(key-one,jwt-1)")
        XCTAssertEqual(second, "signed(key-two,jwt-1)")
    }

    func test_forget_dropsOneWalletAndLeavesTheRest() async {
        let chainKit = ChainKitWalletAuthFake()
        let provider = makeProvider(chainKit: chainKit)
        await provider.warm(walletId: "wallet-1", mnemonic: "one")
        await provider.warm(walletId: "wallet-2", mnemonic: "two")
        _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")

        await provider.forget(walletId: "wallet-1")

        let forgotten = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        let kept = await provider.token(walletId: "wallet-2", accessToken: "jwt-1")
        XCTAssertNil(forgotten)
        XCTAssertEqual(kept, "signed(key-two,jwt-1)")
    }

    func test_wipe_dropsEverything() async {
        let chainKit = ChainKitWalletAuthFake()
        let provider = makeProvider(chainKit: chainKit)
        await provider.warm(walletId: "wallet-1", mnemonic: "one")
        _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")

        await provider.wipe()

        let token = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        XCTAssertNil(token)
    }

    func test_failedDerivation_leavesTheWalletWithoutAToken() async {
        let chainKit = ChainKitWalletAuthFake()
        chainKit.derivationFails = true
        let provider = makeProvider(chainKit: chainKit)

        await provider.warm(walletId: "wallet-1", mnemonic: "phrase")

        let token = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        XCTAssertNil(token)
    }

    func test_emptyIdentifiers_yieldNoToken() async {
        let chainKit = ChainKitWalletAuthFake()
        let provider = makeProvider(chainKit: chainKit)
        await provider.warm(walletId: "wallet-1", mnemonic: "phrase")

        let withoutWalletId = await provider.token(walletId: "", accessToken: "jwt-1")
        let withoutAccessToken = await provider.token(walletId: "wallet-1", accessToken: "")

        XCTAssertNil(withoutWalletId)
        XCTAssertNil(withoutAccessToken)
    }

    /// The passcode that paid for the app key is spent once per install, not once per launch: a
    /// provider that starts cold signs for a wallet it was never warmed with.
    func test_warmedKey_survivesANewProvider() async {
        let chainKit = ChainKitWalletAuthFake()
        let vault = InMemoryKeychainVault()
        await makeProvider(chainKit: chainKit, vault: vault)
            .warm(walletId: "wallet-1", mnemonic: "phrase")

        let token = await makeProvider(chainKit: chainKit, vault: vault)
            .token(walletId: "wallet-1", accessToken: "jwt-1")

        XCTAssertEqual(token, "signed(key-phrase,jwt-1)")
    }

    func test_storedToken_isServedToANewProviderWithoutSigningAgain() async {
        let chainKit = ChainKitWalletAuthFake()
        let vault = InMemoryKeychainVault()
        let provider = makeProvider(chainKit: chainKit, vault: vault)
        await provider.warm(walletId: "wallet-1", mnemonic: "phrase")
        _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")

        let token = await makeProvider(chainKit: chainKit, vault: vault)
            .token(walletId: "wallet-1", accessToken: "jwt-1")

        XCTAssertEqual(token, "signed(key-phrase,jwt-1)")
        XCTAssertEqual(chainKit.signedAccessTokens, ["jwt-1"])
    }

    /// The stored token is matched against a fingerprint of the access token it signed, so a
    /// rotation cannot serve it.
    func test_storedToken_isNotServedForARotatedAccessToken() async {
        let chainKit = ChainKitWalletAuthFake()
        let vault = InMemoryKeychainVault()
        let provider = makeProvider(chainKit: chainKit, vault: vault)
        await provider.warm(walletId: "wallet-1", mnemonic: "phrase")
        _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")

        let rotated = await makeProvider(chainKit: chainKit, vault: vault)
            .token(walletId: "wallet-1", accessToken: "jwt-2")
        // The record now belongs to the rotated access token, so the retired one has to be reminted.
        let retired = await makeProvider(chainKit: chainKit, vault: vault)
            .token(walletId: "wallet-1", accessToken: "jwt-1")

        XCTAssertEqual(rotated, "signed(key-phrase,jwt-2)")
        XCTAssertEqual(retired, "signed(key-phrase,jwt-1)")
        XCTAssertEqual(chainKit.signedAccessTokens, ["jwt-1", "jwt-2", "jwt-1"])
    }

    /// What a 403 buys: the credential the backend refused is dropped from both caches, so the next
    /// request signs a new one instead of replaying the rejected one from memory or the Keychain.
    func test_invalidateToken_remintsOnTheNextRequest() async {
        let chainKit = ChainKitWalletAuthFake()
        let vault = InMemoryKeychainVault()
        let provider = makeProvider(chainKit: chainKit, vault: vault)
        await provider.warm(walletId: "wallet-1", mnemonic: "phrase")
        _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")

        await provider.invalidateToken(walletId: "wallet-1")
        let reminted = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")

        XCTAssertEqual(reminted, "signed(key-phrase,jwt-1)")
        XCTAssertEqual(chainKit.signedAccessTokens, ["jwt-1", "jwt-1"])
        // The Keychain record went with it, so a relaunch does not resurrect the refused credential.
        _ = await makeProvider(chainKit: chainKit, vault: vault)
            .token(walletId: "wallet-1", accessToken: "jwt-1")
        XCTAssertEqual(chainKit.signedAccessTokens, ["jwt-1", "jwt-1"])
    }

    /// The app key is what makes reminting free, so invalidation must never cost a passcode.
    func test_invalidateToken_keepsTheAppKey() async {
        let chainKit = ChainKitWalletAuthFake()
        let vault = InMemoryKeychainVault()
        let provider = makeProvider(chainKit: chainKit, vault: vault)
        await provider.warm(walletId: "wallet-1", mnemonic: "phrase")

        await provider.invalidateToken(walletId: "wallet-1")

        let hasKey = await provider.hasPersistentAppKey(walletId: "wallet-1")
        XCTAssertTrue(hasKey)
        let relaunched = await makeProvider(chainKit: chainKit, vault: vault)
            .token(walletId: "wallet-1", accessToken: "jwt-1")
        XCTAssertEqual(relaunched, "signed(key-phrase,jwt-1)")
    }

    func test_invalidateToken_leavesOtherWalletsAlone() async {
        let chainKit = ChainKitWalletAuthFake()
        let provider = makeProvider(chainKit: chainKit)
        await provider.warm(walletId: "wallet-1", mnemonic: "one")
        await provider.warm(walletId: "wallet-2", mnemonic: "two")
        _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        _ = await provider.token(walletId: "wallet-2", accessToken: "jwt-1")

        await provider.invalidateToken(walletId: "wallet-1")
        _ = await provider.token(walletId: "wallet-2", accessToken: "jwt-1")

        XCTAssertEqual(chainKit.signedAccessTokens, ["jwt-1", "jwt-1"])
    }

    func test_forget_removesOnlyThatWalletFromTheKeychain() async {
        let chainKit = ChainKitWalletAuthFake()
        let vault = InMemoryKeychainVault()
        let provider = makeProvider(chainKit: chainKit, vault: vault)
        await provider.warm(walletId: "wallet-1", mnemonic: "one")
        await provider.warm(walletId: "wallet-2", mnemonic: "two")
        _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")

        await provider.forget(walletId: "wallet-1")

        let relaunched = makeProvider(chainKit: chainKit, vault: vault)
        let forgotten = await relaunched.token(walletId: "wallet-1", accessToken: "jwt-1")
        let kept = await relaunched.token(walletId: "wallet-2", accessToken: "jwt-1")
        XCTAssertNil(forgotten)
        XCTAssertEqual(kept, "signed(key-two,jwt-1)")
    }

    func test_wipe_removesEveryWalletFromTheKeychain() async {
        let chainKit = ChainKitWalletAuthFake()
        let vault = InMemoryKeychainVault()
        let provider = makeProvider(chainKit: chainKit, vault: vault)
        await provider.warm(walletId: "wallet-1", mnemonic: "one")
        await provider.warm(walletId: "wallet-2", mnemonic: "two")
        _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")

        await provider.wipe()

        let relaunched = makeProvider(chainKit: chainKit, vault: vault)
        let first = await relaunched.token(walletId: "wallet-1", accessToken: "jwt-1")
        let second = await relaunched.token(walletId: "wallet-2", accessToken: "jwt-1")
        XCTAssertNil(first)
        XCTAssertNil(second)
    }

    /// A Keychain that could not be read at all is not an answer: remembering it as "no key" would
    /// leave the wallet header-less for the rest of the session.
    func test_unreadableKeychain_isRetried() async {
        let chainKit = ChainKitWalletAuthFake()
        let vault = InMemoryKeychainVault()
        await makeProvider(chainKit: chainKit, vault: vault)
            .warm(walletId: "wallet-1", mnemonic: "phrase")
        vault.readError = TKKeychainError.other(errSecInteractionNotAllowed)

        let relaunched = makeProvider(chainKit: chainKit, vault: vault)
        let whileLocked = await relaunched.token(walletId: "wallet-1", accessToken: "jwt-1")
        vault.readError = nil
        let afterUnlock = await relaunched.token(walletId: "wallet-1", accessToken: "jwt-1")

        XCTAssertNil(whileLocked)
        XCTAssertEqual(afterUnlock, "signed(key-phrase,jwt-1)")
    }

    /// A wallet this install has no key for is asked about on every request, so the absence has to
    /// be remembered rather than read again.
    func test_absentKey_isReadFromTheKeychainOnce() async {
        let vault = InMemoryKeychainVault()
        let provider = makeProvider(chainKit: ChainKitWalletAuthFake(), vault: vault)

        _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        let readsAfterFirstMiss = vault.readCount
        _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-2")

        XCTAssertEqual(vault.readCount, readsAfterFirstMiss)
    }

    /// A refused write costs the next launch a passcode, nothing more: the derived key still serves
    /// this session.
    func test_refusedKeychainWrite_stillMintsForTheSession() async {
        let chainKit = ChainKitWalletAuthFake()
        let vault = InMemoryKeychainVault()
        vault.writeError = TKKeychainError.other(errSecInteractionNotAllowed)
        let provider = makeProvider(chainKit: chainKit, vault: vault)

        await provider.warm(walletId: "wallet-1", mnemonic: "phrase")

        let token = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        XCTAssertEqual(token, "signed(key-phrase,jwt-1)")
    }

    func test_ephemeralKey_mintsOnlyInsideTheScopeAndIsNeverPersisted() async {
        let chainKit = ChainKitWalletAuthFake()
        let vault = InMemoryKeychainVault()
        let provider = makeProvider(chainKit: chainKit, vault: vault)
        let token = await provider.withEphemeralKey(walletId: "wallet-1", mnemonic: "phrase") {
            await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        }
        XCTAssertEqual(token, "signed(key-phrase,jwt-1)")

        let afterScope = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        let afterRelaunch = await makeProvider(chainKit: chainKit, vault: vault)
            .token(walletId: "wallet-1", accessToken: "jwt-1")
        XCTAssertNil(afterScope)
        XCTAssertNil(afterRelaunch)
        XCTAssertEqual(vault.itemCount, 0)
    }

    func test_nestedEphemeralScopes_keepTheKeyUntilTheOuterScopeEnds() async {
        let provider = makeProvider(chainKit: ChainKitWalletAuthFake())
        await provider.withEphemeralKey(walletId: "wallet-1", mnemonic: "phrase") {
            await provider.withEphemeralKey(walletId: "wallet-1", mnemonic: "phrase") {
                let nested = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
                XCTAssertEqual(nested, "signed(key-phrase,jwt-1)")
            }
            let afterNested = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
            XCTAssertEqual(afterNested, "signed(key-phrase,jwt-1)")
        }

        let afterScopes = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        XCTAssertNil(afterScopes)
    }

    func test_concurrentEphemeralScopes_keepTheKeyUntilBothOperationsFinish() async {
        let provider = makeProvider(chainKit: ChainKitWalletAuthFake())
        let gate = TwoPartyGate()
        let tokens = await withTaskGroup(of: String?.self, returning: [String?].self) { group in
            for _ in 0 ..< 2 {
                group.addTask {
                    await provider.withEphemeralKey(walletId: "wallet-1", mnemonic: "phrase") {
                        await gate.arrive()
                        return await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
                    }
                }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }

        XCTAssertEqual(tokens, ["signed(key-phrase,jwt-1)", "signed(key-phrase,jwt-1)"])
        let afterScopes = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        XCTAssertNil(afterScopes)
    }

    func test_thrownOperation_cleansUpTheEphemeralCredential() async {
        struct Failure: Error {}

        let provider = makeProvider(chainKit: ChainKitWalletAuthFake())
        do {
            try await provider.withEphemeralKey(walletId: "wallet-1", mnemonic: "phrase") {
                _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
                throw Failure()
            }
            XCTFail("operation should throw")
        } catch is Failure {
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let token = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        XCTAssertNil(token)
    }

    func test_cancelledOperation_cleansUpTheEphemeralCredential() async {
        let provider = makeProvider(chainKit: ChainKitWalletAuthFake())
        do {
            try await provider.withEphemeralKey(walletId: "wallet-1", mnemonic: "phrase") {
                _ = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
                throw CancellationError()
            }
            XCTFail("operation should throw")
        } catch is CancellationError {
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let token = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        XCTAssertNil(token)
    }

    func test_ephemeralScope_preservesAnExistingPersistentKey() async {
        let chainKit = ChainKitWalletAuthFake()
        let vault = InMemoryKeychainVault()
        let provider = makeProvider(chainKit: chainKit, vault: vault)
        await provider.warm(walletId: "wallet-1", mnemonic: "phrase")

        let relaunchedToken = await provider.withEphemeralKey(walletId: "wallet-1", mnemonic: "phrase") {
            await makeProvider(chainKit: chainKit, vault: vault)
                .token(walletId: "wallet-1", accessToken: "jwt-1")
        }

        XCTAssertEqual(relaunchedToken, "signed(key-phrase,jwt-1)")
    }

    func test_warm_promotesAnEphemeralKeyAndLeaseCleanupDoesNotRemoveIt() async {
        let chainKit = ChainKitWalletAuthFake()
        let vault = InMemoryKeychainVault()
        let provider = makeProvider(chainKit: chainKit, vault: vault)
        await provider.withEphemeralKey(walletId: "wallet-1", mnemonic: "phrase") {
            await provider.warm(walletId: "wallet-1", mnemonic: "phrase")
        }
        let relaunchedToken = await makeProvider(chainKit: chainKit, vault: vault)
            .token(walletId: "wallet-1", accessToken: "jwt-1")

        XCTAssertEqual(relaunchedToken, "signed(key-phrase,jwt-1)")
    }

    /// A lease is also taken when the Keychain could not be read at all, and its cleanup must not
    /// leave the wallet recorded as key-less: the persistent key is still there and has to be
    /// reloaded once the Keychain answers again.
    func test_ephemeralScope_afterAnUnreadableKeychain_leavesTheKeyReloadable() async {
        let chainKit = ChainKitWalletAuthFake()
        let vault = InMemoryKeychainVault()
        await makeProvider(chainKit: chainKit, vault: vault)
            .warm(walletId: "wallet-1", mnemonic: "phrase")

        let relaunched = makeProvider(chainKit: chainKit, vault: vault)
        vault.readError = TKKeychainError.other(errSecInteractionNotAllowed)
        await relaunched.withEphemeralKey(walletId: "wallet-1", mnemonic: "phrase") {
            _ = await relaunched.token(walletId: "wallet-1", accessToken: "jwt-1")
        }
        vault.readError = nil

        let afterUnlock = await relaunched.token(walletId: "wallet-1", accessToken: "jwt-1")
        XCTAssertEqual(afterUnlock, "signed(key-phrase,jwt-1)")
    }

    func test_failedEphemeralDerivation_createsNoLeaseOrCredential() async {
        let chainKit = ChainKitWalletAuthFake()
        chainKit.derivationFails = true
        let provider = makeProvider(chainKit: chainKit)

        let token = await provider.withEphemeralKey(walletId: "wallet-1", mnemonic: "phrase") {
            await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        }

        XCTAssertNil(token)
    }

    /// A widget builds the graph per timeline request and drops it while the load is still running,
    /// so the resolver can go away under a live provider. It has to degrade to an unsigned request
    /// instead of taking the process down, and a token already on disk must still be served.
    func test_resolverGoneAfterWarm_yieldsNoTokenInsteadOfCrashing() async {
        let chainKit = ChainKitWalletAuthFake()
        let vault = InMemoryKeychainVault()
        var owner: ChainKitOwner? = ChainKitOwner(service: chainKit)
        let provider = WalletAuthTokenProvider(
            chainKitService: { [weak owner] in owner?.service },
            store: WalletAuthKeychainStore(keychainVault: vault)
        )
        await provider.warm(walletId: "wallet-1", mnemonic: "phrase")
        let minted = await provider.token(walletId: "wallet-1", accessToken: "jwt-1")
        XCTAssertEqual(minted, "signed(key-phrase,jwt-1)")

        owner = nil

        // Stored under the same access token: served without ever resolving the service.
        let restarted = WalletAuthTokenProvider(
            chainKitService: { nil },
            store: WalletAuthKeychainStore(keychainVault: vault)
        )
        let cached = await restarted.token(walletId: "wallet-1", accessToken: "jwt-1")
        XCTAssertEqual(cached, minted)

        let rotated = await provider.token(walletId: "wallet-1", accessToken: "jwt-2")
        XCTAssertNil(rotated)
        await provider.warm(walletId: "wallet-2", mnemonic: "phrase")
        let warmed = await provider.hasPersistentAppKey(walletId: "wallet-2")
        XCTAssertFalse(warmed)
    }
}

private final class ChainKitOwner {
    let service: ChainKitService

    init(service: ChainKitService) {
        self.service = service
    }
}

private actor TwoPartyGate {
    private var waiter: CheckedContinuation<Void, Never>?

    func arrive() async {
        if let waiter {
            self.waiter = nil
            waiter.resume()
            return
        }
        await withCheckedContinuation { waiter = $0 }
    }
}

private extension WalletAuthTokenProviderTests {
    func makeProvider(
        chainKit: ChainKitWalletAuthFake,
        vault: InMemoryKeychainVault = InMemoryKeychainVault()
    ) -> WalletAuthTokenProvider {
        WalletAuthTokenProvider(
            chainKitService: { chainKit },
            store: WalletAuthKeychainStore(keychainVault: vault)
        )
    }
}

private final class ChainKitWalletAuthFake: ChainKitService, @unchecked Sendable {
    enum Failure: Error {
        case derivation
    }

    var derivationFails = false
    private(set) var signedAccessTokens = [String]()

    func walletAppPrivateKey(mnemonic: String) throws -> Data {
        if derivationFails {
            throw Failure.derivation
        }
        return Data("key-\(mnemonic)".utf8)
    }

    func walletAuthToken(appPrivateKey: Data, accessToken: String) -> String {
        signedAccessTokens.append(accessToken)
        return "signed(\(String(decoding: appPrivateKey, as: UTF8.self)),\(accessToken))"
    }

    func isTransferSupported(asset _: MultichainAsset) -> Bool {
        fatalError("unused")
    }

    func tronPrivateKey(mnemonic _: String) throws -> Data {
        fatalError("unused")
    }

    func makeBatterySendProof(mnemonic _: String, walletId _: String, boc _: String) throws -> String {
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

    func makeWalletRegisterItem(
        mnemonic _: String,
        deviceId _: String,
        challenge _: String,
        state _: MultichainWalletState
    ) throws -> MultichainWalletRegisterItem {
        fatalError("unused")
    }

    func addresses(mnemonic _: String) -> [MultichainWalletAddress] {
        fatalError("unused")
    }

    func makeMnemonic() throws(MultichainMakeMnemonicFailure) -> [String] {
        fatalError("unused")
    }
}
