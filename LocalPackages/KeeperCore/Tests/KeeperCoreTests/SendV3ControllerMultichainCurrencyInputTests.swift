import BigInt
@testable import KeeperCore
import TonSwift
import XCTest

final class SendV3ControllerMultichainCurrencyInputTests: XCTestCase {
    private static let recipient = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"

    /// A GRAM comment goes encrypted only from a wallet whose own keys sign it and whose TON address
    /// stored its key: a hardware wallet never hands its keys over to encrypt it.
    func test_aCommentGoesEncryptedOnlyFromAWalletThatSignsItself() {
        let key = MultichainPublicKey(defaultHex: String(repeating: "cd", count: 32), segWit: "")
        let ledger = WalletKind.Ledger(
            PublicKey(data: Data(repeating: 1, count: 32)),
            .v4R2,
            Wallet.LedgerDevice(deviceId: "device", deviceModel: "Ledger Stax", accountIndex: 0)
        )

        XCTAssertTrue(makeController(wallet: multichainWallet(tonKey: key)).canEncryptComment)
        XCTAssertFalse(makeController(wallet: multichainWallet(kind: ledger, tonKey: key)).canEncryptComment)
        XCTAssertFalse(makeController(wallet: multichainWallet(tonKey: nil)).canEncryptComment)
        XCTAssertFalse(makeController(wallet: makeWallet()).canEncryptComment)
    }

    /// The recipient's key is read only for an account that can read the comment: active or frozen, no
    /// scam, no memo it requires, and a key it holds. An account or key that could not be read is no
    /// answer: it throws, so that it is read again.
    func test_aCommentGoesEncryptedOnlyToAnAccountThatCanReadIt() async throws {
        let key = Data(repeating: 0xAB, count: 32)
        let cases: [(status: String, isScam: Bool?, isMemoRequired: Bool?, expected: String?)] = [
            ("active", false, false, String(repeating: "ab", count: 32)),
            ("frozen", nil, nil, String(repeating: "ab", count: 32)),
            ("uninit", false, false, nil),
            ("nonexist", false, false, nil),
            ("active", true, false, nil),
            ("active", false, true, nil),
        ]

        for (status, isScam, isMemoRequired, expected) in cases {
            let controller = makeController(
                accounts: AccountsFake(status: status, isScam: isScam, isMemoRequired: isMemoRequired),
                accountPublicKey: { _, _ in key }
            )
            let read = try await controller.commentEncryptionKey(recipient: Self.recipient)
            XCTAssertEqual(read, expected, "\(status) scam: \(String(describing: isScam)) memo: \(String(describing: isMemoRequired))")
        }
        let notAnAddress = try await makeController(accountPublicKey: { _, _ in key }).commentEncryptionKey(recipient: "not an address")
        let emptyKey = try await makeController(
            accounts: AccountsFake(status: "active", isScam: false, isMemoRequired: false),
            accountPublicKey: { _, _ in Data() }
        ).commentEncryptionKey(recipient: Self.recipient)
        XCTAssertNil(notAnAddress)
        XCTAssertNil(emptyKey, "an account answering an empty key has none to encrypt to")

        do {
            _ = try await makeController(accountPublicKey: { _, _ in key }).commentEncryptionKey(recipient: Self.recipient)
            XCTFail("expected an account that could not be read to throw")
        } catch {}
        do {
            _ = try await makeController(
                accounts: AccountsFake(status: "active", isScam: false, isMemoRequired: false),
                accountPublicKey: { _, _ in throw Unread() }
            ).commentEncryptionKey(recipient: Self.recipient)
            XCTFail("expected a key that could not be read to throw")
        } catch {}
    }

    /// TonAPI refuses to read a key from an account that holds none, as from a contract that is no wallet:
    /// that account has none to encrypt to. Any other failure is no answer and throws, so that it is read again.
    func test_anAccountTonAPIReadsNoKeyFromHoldsNone() async throws {
        let active = AccountsFake(status: "active", isScam: false, isMemoRequired: false)
        let read = try await makeController(accounts: active, accountPublicKey: { _, _ in
            throw TonAPIError(statusCode: 400, body: Data(#"{"error":"unknown wallet version"}"#.utf8), path: nil)
        }).commentEncryptionKey(recipient: Self.recipient)
        XCTAssertNil(read)
        for statusCode in [404, 429, 500, 503] {
            do {
                _ = try await makeController(accounts: active, accountPublicKey: { _, _ in
                    throw TonAPIError(statusCode: statusCode, body: nil, path: nil)
                }).commentEncryptionKey(recipient: Self.recipient)
                XCTFail("expected \(statusCode) to throw")
            } catch {}
        }
    }

    /// A comment goes encrypted only when it is not blank: chain-kit refuses to encrypt a blank one.
    func test_aBlankCommentCannotGoEncrypted() {
        let controller = makeController()

        XCTAssertTrue(controller.canEncrypt(comment: "deposit 42"))
        XCTAssertTrue(controller.canEncrypt(comment: " gm "))
        XCTAssertFalse(controller.canEncrypt(comment: ""))
        XCTAssertFalse(controller.canEncrypt(comment: " \n\t "))
    }

    func test_multichainCurrencyInputAtBalanceReturnsBalance() {
        let controller = makeController()
        let asset = makeAsset(balance: 100)

        let amount = controller.multichainTokenAmountFromCurrencyInput(
            asset: asset,
            currencyInput: "1"
        )

        XCTAssertEqual(amount, asset.balance)
    }

    func test_multichainCurrencyInputAboveBalanceReturnsAmountAboveBalance() {
        let controller = makeController()
        let asset = makeAsset(balance: 100)

        let amount = controller.multichainTokenAmountFromCurrencyInput(
            asset: asset,
            currencyInput: "1.001"
        )

        XCTAssertEqual(amount, 101)
        XCTAssertGreaterThan(amount, asset.balance)
    }
}

private extension SendV3ControllerMultichainCurrencyInputTests {
    func makeController(
        wallet: Wallet? = nil,
        accounts: AccountService = NoAccounts(),
        accountPublicKey: @escaping (Address, Network) async throws -> Data = { _, _ in throw Unread() }
    ) -> SendV3Controller {
        let keeperInfoStore = KeeperInfoStore(keeperInfoRepository: KeeperInfoRepositoryFake())
        let currencyStore = CurrencyStore(keeperInfoStore: keeperInfoStore)
        let walletsStore = WalletsStore(keeperInfoStore: keeperInfoStore)
        let balanceStore = BalanceStore(
            walletsStore: walletsStore,
            repository: WalletBalanceRepositoryFake()
        )
        let tonRatesStore = TonRatesStore(repository: RatesRepositoryFake())
        let convertedBalanceStore = ConvertedBalanceStore(
            walletsStore: walletsStore,
            balanceStore: balanceStore,
            tonRatesStore: tonRatesStore,
            currencyStore: currencyStore
        )
        return SendV3Controller(
            wallet: wallet ?? makeWallet(),
            balanceStore: convertedBalanceStore,
            dnsService: DNSServiceFake(),
            tonRatesStore: tonRatesStore,
            currencyStore: currencyStore,
            recipientResolver: RecipientResolverFake(),
            amountFormatter: AmountFormatter(),
            multichainAssetBalanceProvider: MultichainAssetBalanceProvider(
                balanceService: MultichainServiceFake(),
                currencyStore: currencyStore
            ),
            accountService: accounts,
            accountPublicKey: accountPublicKey
        )
    }

    /// A multichain wallet of `kind` whose TON address stored `tonKey`.
    func multichainWallet(kind: WalletKind? = nil, tonKey: MultichainPublicKey?) -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: kind ?? .Regular(PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: WalletMetaData(label: "wallet", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(
                walletId: "multichain-wallet",
                addresses: [MultichainWalletAddress(chain: .ton, address: Self.recipient, type: .tonV4R2, publicKey: tonKey)]
            ))
        )
    }

    func makeWallet() -> Wallet {
        let publicKey = PublicKey(data: Data(repeating: 1, count: 32))
        return Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: "wallet", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }

    func makeAsset(balance: BigUInt) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: "eth/mainnet/coin",
                name: "Ether",
                symbol: "ETH",
                decimals: 2,
                image: ""
            ),
            price: MultichainAssetPrice(
                prices: [Currency.USD.code: 1],
                diff24h: [:],
                diff7d: [:]
            ),
            balance: balance
        )
    }
}

private enum SendV3ControllerMultichainCurrencyInputTestError: Error {
    case unused
}

private final class KeeperInfoRepositoryFake: KeeperInfoRepository {
    func getKeeperInfo() throws -> KeeperInfo {
        throw SendV3ControllerMultichainCurrencyInputTestError.unused
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}

private struct WalletBalanceRepositoryFake: WalletBalanceRepositoryV2 {
    func getBalance(address _: FriendlyAddress) throws -> WalletBalance {
        throw SendV3ControllerMultichainCurrencyInputTestError.unused
    }
}

private struct RatesRepositoryFake: RatesRepository {
    func saveRates(_: Rates) throws {}

    func getRates() throws -> Rates {
        Rates(ton: [], usdt: [], jettonRates: [:])
    }
}

private struct DNSServiceFake: DNSService {
    func resolveDomainName(
        _: String,
        addTonPostfix _: Bool,
        network _: Network
    ) async throws -> Domain {
        throw SendV3ControllerMultichainCurrencyInputTestError.unused
    }

    func loadDomainExpirationDate(
        _: String,
        network _: Network
    ) async throws -> Date? {
        throw SendV3ControllerMultichainCurrencyInputTestError.unused
    }
}

private struct RecipientResolverFake: RecipientResolver {
    func resolverRecipient(
        string _: String,
        network _: Network
    ) async throws -> LegacyRecipient {
        throw SendV3ControllerMultichainCurrencyInputTestError.unused
    }

    func resolverTonRecipient(
        string _: String,
        network _: Network
    ) async throws -> TonRecipient {
        throw SendV3ControllerMultichainCurrencyInputTestError.unused
    }
}

/// An account of `status`, flagged as the test says.
private struct AccountsFake: AccountService {
    let status: String
    let isScam: Bool?
    let isMemoRequired: Bool?

    func loadAccount(network _: Network, address: Address) async throws -> Account {
        Account(
            address: address,
            balance: 0,
            status: status,
            name: nil,
            icon: nil,
            isSuspended: nil,
            isWallet: true,
            isScam: isScam,
            isMemoRequired: isMemoRequired
        )
    }

    func loadAccount(network _: Network, domain _: String) async throws -> Account {
        throw Unread()
    }
}

/// An account or key the test does not read.
private struct Unread: Error {}

/// No account can be read.
private struct NoAccounts: AccountService {
    func loadAccount(network _: Network, address _: Address) async throws -> Account {
        throw Unread()
    }

    func loadAccount(network _: Network, domain _: String) async throws -> Account {
        throw Unread()
    }
}
