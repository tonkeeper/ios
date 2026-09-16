import BigInt
@testable import KeeperCore
import TonSwift
import XCTest

final class SendV3ControllerMultichainCurrencyInputTests: XCTestCase {
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
    func makeController() -> SendV3Controller {
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
            wallet: makeWallet(),
            balanceStore: convertedBalanceStore,
            dnsService: DNSServiceFake(),
            tonRatesStore: tonRatesStore,
            currencyStore: currencyStore,
            recipientResolver: RecipientResolverFake(),
            amountFormatter: AmountFormatter(),
            multichainAssetBalanceProvider: MultichainAssetBalanceProvider(
                balanceService: MultichainServiceFake(),
                currencyStore: currencyStore
            )
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
                diff7d: [:],
                diff30d: [:]
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
