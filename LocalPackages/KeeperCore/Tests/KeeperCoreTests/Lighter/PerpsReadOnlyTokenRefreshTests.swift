import ChainKit
import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import PerpsModels
import TKPerpsAPI
import TonSwift
import XCTest

final class PerpsReadOnlyTokenRefreshTests: XCTestCase {
    func testDepositAcceptsAnAlreadyBoundAddressWithoutUnlockingAgain() async throws {
        let address = try XCTUnwrap(makeWallet().multichainAddress(for: .eth))
        let service = makeService(api: AccountStubAPI(account: .init(l1_address: address.uppercased(), status: .not_registered)))

        try await service.ensureDepositBinding(wallet: makeWallet(), passcode: "unused")
    }

    func testDepositRejectsAnAccountBoundToAnotherAddress() async throws {
        let service = makeService(api: AccountStubAPI(account: .init(l1_address: "0x00000000000000000000000000000000000000aa")))
        do {
            try await service.ensureDepositBinding(wallet: makeWallet(), passcode: "unused")
            XCTFail("a deposit must not use a different bound address")
        } catch {
            XCTAssertEqual(error as? PerpsTradingError, .validation("deposit account address does not match the wallet"))
        }
    }

    func testAnExistingTokenStillThrottlesAccountReads() async {
        let calls = AccountCalls()
        let api = AccountStubAPI(account: .init(has_ro_token: true)) { await calls.record() }
        let service = makeService(api: api)

        _ = await service.refreshReadOnlyToken(wallet: makeWallet())
        _ = await service.refreshReadOnlyToken(wallet: makeWallet())

        let count = await calls.count
        XCTAssertEqual(count, 1)
    }

    func testConcurrentRefreshesReserveOneAccountRead() async {
        let calls = AccountCalls()
        let api = AccountStubAPI(account: .init(has_ro_token: true)) { await calls.record() }
        let service = makeService(api: api)
        let wallet = makeWallet()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 20 {
                group.addTask { _ = await service.refreshReadOnlyToken(wallet: wallet) }
            }
        }

        let count = await calls.count
        XCTAssertEqual(count, 1)
    }

    func testACallArrivingMidMintTakesThatMintsAnswer() async throws {
        let issues = AccountCalls()
        let release = IssueRelease()
        let api = AccountStubAPI(account: .init(has_ro_token: true), onIssueReadOnlyToken: {
            await issues.record()
            await release.wait()
        })
        let vault = InMemoryKeychainVault()
        let service = makeService(api: api, vault: vault)
        let wallet = makeWallet()
        let credentials = LighterCredentialsStore(keychainVault: vault, walletId: wallet.id, environment: PerpsEnvironment.storage)
        try credentials.saveAccount(PerpsStoredAccount(accountIndex: 7, apiKeyIndex: 3))
        try credentials.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))

        let first = Task { await service.ensureReadOnlyToken(wallet: wallet) }
        while await issues.count == 0 {
            await Task.yield()
        }
        let joining = Task { await service.ensureReadOnlyToken(wallet: wallet) }
        let refreshing = Task { await service.refreshReadOnlyToken(wallet: wallet) }
        try await Task.sleep(nanoseconds: 100_000_000)
        await release.open()

        let firstIssued = await first.value
        let joinedIssued = await joining.value
        let refreshed = await refreshing.value
        XCTAssertTrue(firstIssued)
        XCTAssertTrue(joinedIssued)
        XCTAssertTrue(refreshed)
        let count = await issues.count
        XCTAssertEqual(count, 1)
    }

    func testAForcedRefreshIsNotHeldBackByTheReadThrottle() async {
        let calls = AccountCalls()
        let api = AccountStubAPI(account: .init(has_ro_token: true)) { await calls.record() }
        let service = makeService(api: api)

        _ = await service.refreshReadOnlyToken(wallet: makeWallet())
        _ = await service.refreshReadOnlyToken(wallet: makeWallet(), force: true)

        let count = await calls.count
        XCTAssertEqual(count, 2)
    }

    func testFailedAccountReadsAreThrottledToo() async {
        let calls = AccountCalls()
        let api = AccountStubAPI(account: .init()) {
            await calls.record()
            throw AccountStubAPI.Unsupported()
        }
        let service = makeService(api: api)

        _ = await service.refreshReadOnlyToken(wallet: makeWallet())
        _ = await service.refreshReadOnlyToken(wallet: makeWallet())

        let count = await calls.count
        XCTAssertEqual(count, 1)
    }

    func testThrottleExpiresWithoutBlockingTheNextRead() async {
        let calls = AccountCalls()
        let clock = RefreshClock()
        let api = AccountStubAPI(account: .init(has_ro_token: true)) { await calls.record() }
        let service = makeService(api: api, now: { clock.now })
        _ = await service.refreshReadOnlyToken(wallet: makeWallet())
        clock.advance(by: 59)
        _ = await service.refreshReadOnlyToken(wallet: makeWallet())
        let beforeExpiry = await calls.count
        XCTAssertEqual(beforeExpiry, 1)

        clock.advance(by: 1)
        _ = await service.refreshReadOnlyToken(wallet: makeWallet())

        let afterExpiry = await calls.count
        XCTAssertEqual(afterExpiry, 2)
    }

    func testClearingCredentialsResetsTheReadThrottle() async {
        let calls = AccountCalls()
        let api = AccountStubAPI(account: .init(has_ro_token: true)) { await calls.record() }
        let service = makeService(api: api)
        let wallet = makeWallet()
        _ = await service.refreshReadOnlyToken(wallet: wallet)

        service.clearCredentials(wallet: wallet)
        _ = await service.refreshReadOnlyToken(wallet: wallet)

        let count = await calls.count
        XCTAssertEqual(count, 2)
    }

    func testWalletsDoNotShareTheReadThrottle() async {
        let calls = AccountCalls()
        let api = AccountStubAPI(account: .init(has_ro_token: true)) { await calls.record() }
        let service = makeService(api: api)

        _ = await service.refreshReadOnlyToken(wallet: makeWallet(id: "first"))
        _ = await service.refreshReadOnlyToken(wallet: makeWallet(id: "second"))

        let count = await calls.count
        XCTAssertEqual(count, 2)
    }

    func testAKeyStoredUnderTheAccountIndexDerivationHasNoTradingSession() async throws {
        let vault = InMemoryKeychainVault()
        let service = makeService(api: AccountStubAPI(account: .init()), vault: vault)
        let wallet = makeWallet()
        let credentials = LighterCredentialsStore(keychainVault: vault, walletId: wallet.id, environment: PerpsEnvironment.storage)
        try credentials.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))

        try credentials.saveAccount(PerpsStoredAccount(accountIndex: 7, apiKeyIndex: 3))
        let legacy = try await service.tradingSession(wallet: wallet)
        XCTAssertNil(legacy)

        try credentials.saveAccount(PerpsStoredAccount(accountIndex: 7, apiKeyIndex: 3, keyDerivationIndex: 0))
        let migrated = try await service.tradingSession(wallet: wallet)
        XCTAssertEqual(migrated?.accountIndex, 7)
    }

    func testTheKeyAFirstDepositRegisteredIsAdoptedWithoutAnUnlock() async throws {
        let key = Data(repeating: 0xAB, count: 40)
        let ownKey = PerpsAccountService.tradingPublicKey(privateKey: key)
        let foreignKey = "0x" + String(repeating: "cd", count: 40)
        let cases: [(String, [Components.Schemas.AccountAPIKey]?, Bool)] = [
            ("own key", [.init(api_key_index: 3, public_key: ownKey.uppercased())], true),
            ("another slot", [.init(api_key_index: 0, public_key: ownKey)], false),
            ("another key", [.init(api_key_index: 3, public_key: foreignKey)], false),
            ("keys not listed", nil, false),
        ]
        for (name, keys, adopted) in cases {
            let vault = InMemoryKeychainVault()
            let service = makeService(api: AccountStubAPI(account: .init(account_index: 7, has_l2_key: true, api_keys: keys)), vault: vault)
            let wallet = makeWallet()
            try LighterCredentialsStore(keychainVault: vault, walletId: wallet.id, environment: PerpsEnvironment.storage).saveL2PrivateKey(key)

            let result = await service.adoptRegisteredTradingKey(wallet: wallet)

            XCTAssertEqual(result, adopted, name)
            let session = try await service.tradingSession(wallet: wallet)
            XCTAssertEqual(session?.accountIndex, adopted ? 7 : nil, name)
        }
    }

    /// Without the token the account's orders read as none, and limit orders are refused.
    func testAnAdoptedAccountGetsItsReadOnlyToken() async throws {
        let key = Data(repeating: 0xAB, count: 40)
        let issues = AccountCalls()
        let api = AccountStubAPI(
            account: .init(
                account_index: 7,
                l1_address: "0x7ecebaf27c989adef9ea3dd06d316f6f463a5109",
                has_l2_key: true,
                has_ro_token: false,
                api_keys: [.init(api_key_index: 3, public_key: PerpsAccountService.tradingPublicKey(privateKey: key))]
            ),
            onIssueReadOnlyToken: { await issues.record() }
        )
        let vault = InMemoryKeychainVault()
        let service = makeService(api: api, vault: vault)
        let wallet = makeWallet()
        try LighterCredentialsStore(keychainVault: vault, walletId: wallet.id, environment: PerpsEnvironment.storage).saveL2PrivateKey(key)
        WalletAuthKeychainStore(keychainVault: vault).saveAppKey(Data(repeating: 0x11, count: 32), walletId: wallet.id)

        let adopted = await service.adoptRegisteredTradingKey(wallet: wallet)

        XCTAssertTrue(adopted)
        let issued = await issues.count
        XCTAssertEqual(issued, 1)
    }

    func testAdoptionAsksNothingWithoutAKeptKeyOrOnceTheAccountIsRecorded() async throws {
        let calls = AccountCalls()
        let vault = InMemoryKeychainVault()
        let service = makeService(api: AccountStubAPI(account: .init(account_index: 7, has_l2_key: true, api_keys: [])) { await calls.record() }, vault: vault)
        let wallet = makeWallet()
        let credentials = LighterCredentialsStore(keychainVault: vault, walletId: wallet.id, environment: PerpsEnvironment.storage)

        let withoutKey = await service.adoptRegisteredTradingKey(wallet: wallet)
        try credentials.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        try credentials.saveAccount(PerpsStoredAccount(accountIndex: 7, apiKeyIndex: 3))
        let recorded = await service.adoptRegisteredTradingKey(wallet: wallet)

        XCTAssertFalse(withoutKey)
        XCTAssertFalse(recorded)
        let count = await calls.count
        XCTAssertEqual(count, 0)
    }

    func testAKeyIsHeldOnlyOnceKeptAndAnUnreadableMnemonicKeepsNone() async throws {
        let vault = InMemoryKeychainVault()
        let service = makeService(api: AccountStubAPI(account: .init()), vault: vault)
        let wallet = makeWallet()

        let kept = await service.keepTradingKey(wallet: wallet, passcode: "1111")
        let heldBeforeKeeping = service.holdsKeptTradingKey(wallet: wallet)
        try LighterCredentialsStore(keychainVault: vault, walletId: wallet.id, environment: PerpsEnvironment.storage)
            .saveL2PrivateKey(Data(repeating: 0xAB, count: 40))

        XCTAssertFalse(kept)
        XCTAssertFalse(heldBeforeKeeping)
        XCTAssertTrue(service.holdsKeptTradingKey(wallet: wallet))
    }

    func testATierReadWithoutAUsableTokenReissuesItAndUpgrades() async throws {
        let issues = AccountCalls()
        let changes = TierChanges()
        let api = AccountStubAPI(
            account: .init(l1_address: "0x7ecebaf27c989adef9ea3dd06d316f6f463a5109", has_ro_token: true),
            onIssueReadOnlyToken: { await issues.record() },
            onAccountTier: {
                guard await issues.count > 0 else {
                    throw PerpsAPIError.badStatus(.init(
                        httpStatus: 400,
                        code: "readonly_token_unavailable",
                        message: nil,
                        retryable: false,
                        reason: nil
                    ))
                }
                return .init(id: "0", name: "standard")
            },
            onChangeAccountTier: { await changes.record($0) }
        )
        let vault = InMemoryKeychainVault()
        let service = makeService(api: api, vault: vault)
        let wallet = makeWallet()
        let credentials = LighterCredentialsStore(keychainVault: vault, walletId: wallet.id, environment: PerpsEnvironment.storage)
        try credentials.saveAccount(PerpsStoredAccount(accountIndex: 7, apiKeyIndex: 3))
        try credentials.saveL2PrivateKey(Data(repeating: 0xAB, count: 40))
        WalletAuthKeychainStore(keychainVault: vault).saveAppKey(Data(repeating: 0x11, count: 32), walletId: wallet.id)

        await service.ensurePlusTier(wallet: wallet, trigger: .resolve)

        let issued = await issues.count
        let tiers = await changes.tiers
        XCTAssertEqual(issued, 1)
        XCTAssertEqual(tiers, ["plus"])
    }
}

private extension PerpsReadOnlyTokenRefreshTests {
    func makeService(
        api: PerpsAPI,
        vault: InMemoryKeychainVault = InMemoryKeychainVault(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> PerpsAccountService {
        let client = CryptoKitClient(netModule: ModuleNetModule(netConfig: ModuleNetConfig(
            isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil
        )))
        return PerpsAccountService(
            mnemonicAccess: .disabled(mnemonicsRepository: .init(
                rn: RNMnemonicsVault(keychainVault: vault),
                native: MnemonicsVault(keychainVault: vault, seedProvider: { "unused" })
            )),
            keychainVault: vault,
            perpsAPI: api,
            bindSigner: PerpsAccountBindSigner(client: client),
            walletAuthTokenProvider: UnusedWalletAuth(),
            chainKitClient: client,
            now: now
        )
    }

    func makeWallet(id: String = "perps-refresh") -> Wallet {
        Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: WalletMetaData(label: "Perps", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(walletId: id, addresses: [.init(chain: .eth, address: "0x7ecebaf27c989adef9ea3dd06d316f6f463a5109")], syncState: .synced))
        )
    }
}

private actor AccountCalls {
    private(set) var count = 0
    func record() {
        count += 1
    }
}

private actor TierChanges {
    private(set) var tiers: [String] = []
    func record(_ tier: String) {
        tiers.append(tier)
    }
}

private actor IssueRelease {
    private var isOpen = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func open() {
        isOpen = true
        waiting.forEach { $0.resume() }
        waiting = []
    }
}

private final class RefreshClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1000)
    var now: Date {
        lock.withLock { date }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { date.addTimeInterval(interval) }
    }
}

private struct UnusedWalletAuth: WalletAuthTokenProviding {
    func token(walletId _: String, accessToken _: String) async -> String? {
        nil
    }

    func invalidateToken(walletId _: String) async {}
    func hasPersistentAppKey(walletId _: String) async -> Bool {
        false
    }

    func warm(walletId _: String, mnemonic _: String) async {}
    func persistAppKey(_: Data, walletId _: String) async {}
    func forget(walletId _: String) async {}
    func wipe() async {}
}
