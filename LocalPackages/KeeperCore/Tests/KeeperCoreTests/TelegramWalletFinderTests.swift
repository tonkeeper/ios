@testable import KeeperCore
import KeeperCoreComponents
import KeeperCoreSensitive
import TKTestSupport
import TonSwift
import XCTest

final class TelegramWalletFinderTests: XCTestCase {
    private let words = Array(repeating: "abandon", count: 11) + ["about"]

    func test_active_wallet_tg_with_phrase_key_is_found() async throws {
        let loader = try AccountLoaderStub(status: "active", balance: 5, interfaces: ["walletTg"], publicKey: phraseKey())

        let lookup = await makeFinder(loader: loader).find(words: words, network: .mainnet)

        guard case let .found(wallet) = lookup else { return XCTFail("\(lookup)") }
        XCTAssertEqual(wallet.revision, .walletTg)
        XCTAssertEqual(wallet.address, try telegramAddress())
        XCTAssertEqual(wallet.balance.tonBalance.amount, 5)
    }

    func test_active_wallet_tg_with_rotated_key_is_not_offered() async {
        let loader = AccountLoaderStub(status: "active", balance: 5, interfaces: ["walletTg"], publicKey: Data(repeating: 1, count: 32))

        let lookup = await makeFinder(loader: loader).find(words: words, network: .mainnet)

        guard case .none = lookup else { return XCTFail("\(lookup)") }
    }

    func test_active_account_of_other_interface_is_not_offered() async {
        let loader = AccountLoaderStub(status: "active", balance: 5, interfaces: ["wallet_v4r2"])

        let lookup = await makeFinder(loader: loader).find(words: words, network: .mainnet)

        guard case .none = lookup else { return XCTFail("\(lookup)") }
        XCTAssertEqual(loader.publicKeyRequests, 0)
    }

    func test_uninit_wallet_with_funds_is_found() async {
        let loader = AccountLoaderStub(status: "uninit", balance: 1)

        let lookup = await makeFinder(loader: loader).find(words: words, network: .mainnet)

        guard case .found = lookup else { return XCTFail("\(lookup)") }
    }

    func test_empty_uninit_and_nonexist_are_not_offered() async {
        for (status, balance) in [("uninit", Int64(0)), ("nonexist", Int64(0))] {
            let lookup = await makeFinder(loader: AccountLoaderStub(status: status, balance: balance))
                .find(words: words, network: .mainnet)
            guard case .none = lookup else { return XCTFail("\(status): \(lookup)") }
        }
    }

    func test_failed_request_is_reported() async {
        let lookup = await makeFinder(loader: AccountLoaderStub(error: URLError(.notConnectedToInternet)))
            .find(words: words, network: .mainnet)

        guard case let .failed(error) = lookup else { return XCTFail("\(lookup)") }
        XCTAssertTrue(error.isNoConnectionError)
    }

    func test_failed_public_key_request_is_reported() async {
        let loader = AccountLoaderStub(status: "active", balance: 5, interfaces: ["walletTg"], publicKeyError: URLError(.timedOut))

        let lookup = await makeFinder(loader: loader).find(words: words, network: .mainnet)

        guard case .failed = lookup else { return XCTFail("\(lookup)") }
    }

    func test_added_wallet_with_key_is_not_offered_again() async throws {
        let loader = AccountLoaderStub(status: "uninit", balance: 1)
        let added = try makeWallet(kind: .Regular(TonSwift.PublicKey(data: phraseKey()), .walletTg))

        let lookup = await makeFinder(loader: loader, wallets: [added]).find(words: words, network: .mainnet)

        guard case .none = lookup else { return XCTFail("\(lookup)") }
        XCTAssertEqual(loader.accountRequests, 0)
    }

    func test_watch_only_copy_does_not_count_as_added() async throws {
        let loader = AccountLoaderStub(status: "uninit", balance: 1)
        let watchOnly = try makeWallet(kind: .Watchonly(.Resolved(telegramAddress())))

        let lookup = await makeFinder(loader: loader, wallets: [watchOnly]).find(words: words, network: .mainnet)

        guard case .found = lookup else { return XCTFail("\(lookup)") }
    }
}

private extension TelegramWalletFinderTests {
    func phraseKey() throws -> Data {
        try CoreMnemonic(mnemonicWords: words, type: .bip39).toKeyPair().publicKey.data
    }

    func telegramAddress() throws -> Address {
        try WalletTg(publicKey: phraseKey(), network: .mainnet).address()
    }

    func makeFinder(
        loader: AccountLoaderStub,
        wallets: [Wallet] = []
    ) -> TelegramWalletFinder {
        TelegramWalletFinder(accountLoader: loader, addedWallets: { wallets })
    }

    func makeWallet(kind: WalletKind) -> Wallet {
        Wallet(
            id: UUID().uuidString,
            identity: WalletIdentity(network: .mainnet, kind: kind),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}

final class AccountLoaderStub: TelegramWalletAccountLoader, @unchecked Sendable {
    private let status: String
    private let balance: Int64
    private let interfaces: [String]
    private let publicKey: Data
    private let error: Error?
    private let publicKeyError: Error?
    private let accountGate: TestGate?
    private(set) var accountRequests = 0
    private(set) var publicKeyRequests = 0

    init(
        status: String = "nonexist",
        balance: Int64 = 0,
        interfaces: [String] = [],
        publicKey: Data = Data(),
        error: Error? = nil,
        publicKeyError: Error? = nil,
        accountGate: TestGate? = nil
    ) {
        self.status = status
        self.balance = balance
        self.interfaces = interfaces
        self.publicKey = publicKey
        self.error = error
        self.publicKeyError = publicKeyError
        self.accountGate = accountGate
    }

    func account(address: Address, network: Network) async throws -> Account {
        accountRequests += 1
        try await accountGate?.wait()
        if let error { throw error }
        return Account(
            address: address,
            balance: balance,
            status: status,
            name: nil,
            icon: nil,
            isSuspended: nil,
            isWallet: true,
            isScam: nil,
            isMemoRequired: nil,
            interfaces: interfaces
        )
    }

    func publicKey(address: Address, network: Network) async throws -> Data {
        publicKeyRequests += 1
        if let publicKeyError { throw publicKeyError }
        return publicKey
    }
}
