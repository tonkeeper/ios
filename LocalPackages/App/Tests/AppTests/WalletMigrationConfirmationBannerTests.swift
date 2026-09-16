@testable import App
import BigInt
@testable import KeeperCore
import TKCore
import TonSwift
import TronSwift
import XCTest

@MainActor
final class WalletMigrationConfirmationBannerTests: XCTestCase {
    func test_silentServerShortageShowsConfirmationWithBatteryOption() async {
        var presented: InsufficientFeePopupContent?
        let viewModel = makeViewModel(
            prepare: makePrepareResult(
                methods: [.ton(amountNano: 67_000_000), .battery(charges: 20)],
                availableTonNano: 19_900_000,
                requiredTonNano: nil
            ),
            availableBatteryCharges: 5,
            onPresentInsufficientFee: { presented = $0 }
        )

        await viewModel.start()

        XCTAssertEqual(viewModel.state, .ready)
        XCTAssertNil(presented)
        XCTAssertEqual(viewModel.selectedTonFeeMethod, .ton(amountNano: 67_000_000))
        XCTAssertTrue(viewModel.tonFeeRowModel?.canPickMethod == true)
    }

    func test_reportedTonShortageShowsConfirmationWhenBatteryIsOffered() async {
        var presented: InsufficientFeePopupContent?
        let viewModel = makeViewModel(
            prepare: makePrepareResult(
                methods: [.ton(amountNano: 250_000), .battery(charges: 6)],
                availableTonNano: 10000,
                requiredTonNano: 250_000
            ),
            availableBatteryCharges: nil,
            onPresentInsufficientFee: { presented = $0 }
        )

        await viewModel.start()

        XCTAssertEqual(viewModel.state, .ready)
        XCTAssertNil(presented)
    }

    func test_tonShortageWithTronAndUnpayableBatteryKeepsContinueBanner() async {
        var presented: InsufficientFeePopupContent?
        let viewModel = makeViewModel(
            prepare: makePrepareResult(
                methods: [.ton(amountNano: 67_000_000), .battery(charges: 20)],
                availableTonNano: 19_900_000,
                requiredTonNano: nil
            ),
            tronPrepare: makeTronPrepareResult(),
            availableBatteryCharges: 5,
            onPresentInsufficientFee: { presented = $0 }
        )

        await viewModel.start()

        XCTAssertEqual(
            viewModel.state,
            .failed(.insufficientTonSoft(.init(required: 67_000_000, available: 19_900_000)))
        )
        XCTAssertTrue(viewModel.showsContinueOnFailure)
        XCTAssertNotNil(presented)
    }

    func test_tonShortageWithoutBatteryStillRaisesDepositBanner() async {
        var presented: InsufficientFeePopupContent?
        let viewModel = makeViewModel(
            prepare: makePrepareResult(
                methods: [.ton(amountNano: 67_000_000)],
                availableTonNano: 19_900_000,
                requiredTonNano: nil
            ),
            availableBatteryCharges: 5,
            onPresentInsufficientFee: { presented = $0 }
        )

        await viewModel.start()

        XCTAssertEqual(
            viewModel.state,
            .failed(.insufficientTonSoft(.init(required: 67_000_000, available: 19_900_000)))
        )
        XCTAssertNotNil(presented)
    }

    func test_coveredBalanceRaisesNoBanner() async {
        var presented: InsufficientFeePopupContent?
        let viewModel = makeViewModel(
            prepare: makePrepareResult(
                methods: [.ton(amountNano: 10000)],
                availableTonNano: 1_000_000,
                requiredTonNano: nil
            ),
            availableBatteryCharges: nil,
            onPresentInsufficientFee: { presented = $0 }
        )

        await viewModel.start()

        XCTAssertNil(presented)
    }
}

private extension WalletMigrationConfirmationBannerTests {
    func makeViewModel(
        prepare: WalletMigrationPrepareResult,
        tronPrepare: WalletMigrationTronPrepareResult? = nil,
        availableBatteryCharges: Int?,
        onPresentInsufficientFee: @escaping (InsufficientFeePopupContent) -> Void
    ) -> WalletMigrationConfirmationViewModel {
        let sourceWallet = makeWallet(id: "source", publicKeySeed: 1)
        let destinationWallet = makeWallet(id: "destination", publicKeySeed: 2)
        let repository = KeeperInfoRepositoryStub(
            keeperInfo: KeeperInfo(
                wallets: [sourceWallet, destinationWallet],
                currentWallet: sourceWallet,
                currency: .defaultCurrency,
                securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
                appSettings: KeeperInfo.AppSettings(isSecureMode: false, searchEngine: .duckduckgo),
                country: .auto
            )
        )
        let keeperInfoStore = KeeperInfoStore(keeperInfoRepository: repository)
        let coreAssembly = CoreAssembly()

        return WalletMigrationConfirmationViewModel(
            sourceWallet: sourceWallet,
            destinationWallet: destinationWallet,
            walletMigrationService: WalletMigrationServiceStub(
                prepare: prepare,
                tronPrepare: tronPrepare,
                availableBatteryCharges: availableBatteryCharges
            ),
            nftService: NFTServiceStub(),
            amountFormatter: KeeperCore.FormattersAssembly().amountFormatter,
            currencyStore: CurrencyStore(keeperInfoStore: keeperInfoStore),
            appSettingsStore: AppSettingsStore(keeperInfoStore: keeperInfoStore),
            walletNFTsRepository: WalletNFTsRepositoryStub(),
            ratesService: RatesServiceStub(),
            tonRatesStore: TonRatesStore(repository: RatesRepositoryStub()),
            analyticsProvider: AnalyticsProvider(
                analyticsServices: [],
                uniqueIdProvider: coreAssembly.uniqueIdProvider,
                appInfoProvider: coreAssembly.appInfoProvider,
                keysCountryCodeProvider: coreAssembly.keysCountryCodeProvider
            ),
            onPresentInsufficientFee: onPresentInsufficientFee
        )
    }

    func makePrepareResult(
        methods: [WalletMigrationPrepareResult.FeeMethod],
        availableTonNano: UInt64?,
        requiredTonNano: UInt64?
    ) -> WalletMigrationPrepareResult {
        let sourceAddress = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"
        let destinationAddress = "0:0000000000000000000000000000000000000000000000000000000000000002"

        return WalletMigrationPrepareResult(
            from: sourceAddress,
            to: destinationAddress,
            walletVersion: "v4R2",
            transactions: [
                makePreparedTransaction(
                    sourceAddress: sourceAddress,
                    destinationAddress: destinationAddress
                ),
            ],
            batteryTransactions: nil,
            availableFeeMethods: methods,
            availableTonNano: availableTonNano,
            requiredTonNano: requiredTonNano
        )
    }

    func makePreparedTransaction(
        sourceAddress: String,
        destinationAddress: String
    ) -> WalletMigrationPreparedTransaction {
        let source = try! TonSwift.Address.parse(sourceAddress)
        let destination = try! TonSwift.Address.parse(destinationAddress)
        let sourceAccount = WalletAccount(address: source, name: nil, isScam: false, isWallet: true)
        let destinationAccount = WalletAccount(address: destination, name: nil, isScam: false, isWallet: true)

        return WalletMigrationPreparedTransaction(
            seqno: 1,
            boc: "te6cckEBAQEAAgAAAA==",
            event: AccountEvent(
                eventId: "1",
                date: Date(timeIntervalSince1970: 0),
                account: sourceAccount,
                isScam: false,
                isInProgress: false,
                extra: .Fee(1000),
                excess: nil,
                progress: nil,
                actions: [
                    AccountEventAction(
                        type: .tonTransfer(
                            AccountEventAction.TonTransfer(
                                sender: sourceAccount,
                                recipient: destinationAccount,
                                amount: 1_000_000_000,
                                comment: nil,
                                encryptedComment: nil
                            )
                        ),
                        status: .ok,
                        preview: AccountEventAction.SimplePreview(
                            name: "TON",
                            description: "",
                            image: nil,
                            value: "1 GRAM",
                            fiatValue: nil,
                            valueImage: nil,
                            accounts: [destinationAccount]
                        )
                    ),
                ]
            ),
            totalFees: 1000,
            totalEquivalent: 1,
            sponsored: false
        )
    }

    func makeTronPrepareResult() -> WalletMigrationTronPrepareResult {
        WalletMigrationTronPrepareResult(
            sourceAddress: "source",
            destinationAddress: "destination",
            usdtAmount: 1,
            requiredTRXSun: 50,
            availableTRXSun: 100,
            energy: 0,
            bandwidth: 0,
            availableFeeMethods: [.trx(amountSun: BigUInt(50))]
        )
    }

    func makeWallet(id: String, publicKeySeed: UInt8) -> Wallet {
        Wallet(
            id: id,
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(
                    TonSwift.PublicKey(data: Data(repeating: publicKeySeed, count: 32)),
                    .v4R2
                )
            ),
            metaData: WalletMetaData(
                label: "Wallet \(id)",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: .unavailable
        )
    }
}

private enum BannerTestError: Error {
    case unsupported
}

private actor WalletMigrationServiceStub: WalletMigrationService {
    private let prepare: WalletMigrationPrepareResult
    private let tronPrepare: WalletMigrationTronPrepareResult?
    private let charges: Int?

    init(
        prepare: WalletMigrationPrepareResult,
        tronPrepare: WalletMigrationTronPrepareResult? = nil,
        availableBatteryCharges: Int?
    ) {
        self.prepare = prepare
        self.tronPrepare = tronPrepare
        charges = availableBatteryCharges
    }

    func prepareMigration(
        from sourceWallet: Wallet,
        to destinationWallet: Wallet,
        currency: Currency
    ) async throws -> WalletMigrationPrepareResult {
        prepare
    }

    func prepareTronMigration(
        from sourceWallet: Wallet,
        to destinationWallet: Wallet
    ) async throws -> WalletMigrationTronPrepareResult? {
        tronPrepare
    }

    func availableBatteryCharges(wallet: Wallet) async -> Int? {
        charges
    }

    func getMigrationWallets(
        wallets: [Wallet],
        currency: Currency
    ) async throws -> [WalletMigrationWalletValue] {
        throw BannerTestError.unsupported
    }
}

private struct NFTServiceStub: NFTService {
    func loadNFTs(addresses: [TonSwift.Address], network: Network) async throws -> [TonSwift.Address: NFT] {
        [:]
    }

    func getNFT(address: TonSwift.Address, network: Network) throws -> NFT {
        throw BannerTestError.unsupported
    }

    func saveNFT(nft: NFT, network: Network) throws {}

    func changeSuspiciousState(_ nft: NFT, network: Network, isScam: Bool) async throws {
        throw BannerTestError.unsupported
    }
}

private struct WalletNFTsRepositoryStub: WalletNFTsRepository {
    func get(wallet: Wallet) -> WalletNFTs {
        .empty
    }

    func save(nfts: WalletNFTs, wallet: Wallet) throws {}
}

private struct RatesServiceStub: RatesService {
    func loadRates(jettons: [String], currencies: [Currency]) async throws -> Rates {
        throw BannerTestError.unsupported
    }
}

private struct RatesRepositoryStub: RatesRepository {
    func saveRates(_ rates: Rates) throws {}

    func getRates() throws -> Rates {
        throw BannerTestError.unsupported
    }
}

private final class KeeperInfoRepositoryStub: KeeperInfoRepository {
    private let keeperInfo: KeeperInfo

    init(keeperInfo: KeeperInfo) {
        self.keeperInfo = keeperInfo
    }

    func getKeeperInfo() throws -> KeeperInfo {
        keeperInfo
    }

    func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}
