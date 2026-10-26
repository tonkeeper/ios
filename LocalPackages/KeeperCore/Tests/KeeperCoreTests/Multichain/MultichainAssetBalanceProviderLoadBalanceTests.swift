import BigInt
@testable import KeeperCore
import TonSwift
import XCTest

final class MultichainAssetBalanceProviderLoadBalanceTests: XCTestCase {
    private let state = MultichainWalletState(walletId: "wallet-id", addresses: [])
    private let trxAssetId = "tron/mainnet/coin"
    private let usdtAssetId = "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"

    /// TK-2638: a wallet holding no TRX is simply missing from the listing, and reporting that as
    /// an unknown balance let the fee picker treat TRX as payable.
    func test_assetMissingFromCompleteListing_resolvesToZero() async {
        let provider = makeProvider(assets: .listing([makeAsset(assetId: "ton/mainnet/coin", balance: 5)]))

        let balance = await provider.loadBalance(for: trxAssetId, multichainState: state)

        XCTAssertEqual(balance, 0)
    }

    func test_assetPresentInListing_resolvesToItsBalance() async {
        let provider = makeProvider(assets: .listing([makeAsset(assetId: trxAssetId, balance: 4_300_000)]))

        let balance = await provider.loadBalance(for: trxAssetId, multichainState: state)

        XCTAssertEqual(balance, 4_300_000)
    }

    func test_failedListingWithoutCache_keepsBalanceUnknown() async {
        let provider = makeProvider(assets: .failure)

        let balance = await provider.loadBalance(for: trxAssetId, multichainState: state)

        XCTAssertNil(balance)
    }

    /// A known zero has to outrank an older positive balance: otherwise the sequence
    /// "cached TRX > 0 → listing without TRX → failed refresh" hands the fee decision a balance the
    /// wallet no longer has.
    func test_failedListingAfterKnownZero_keepsZero() async {
        let provider = makeProvider(
            script: .init([
                .listing([makeAsset(assetId: "ton/mainnet/coin", balance: 5)]),
                .failure,
            ])
        )
        provider.primeCache(
            assets: [makeAsset(assetId: trxAssetId, balance: 99)],
            multichainState: state
        )

        let known = await provider.loadBalance(for: trxAssetId, multichainState: state)
        let afterFailure = await provider.loadBalance(for: trxAssetId, multichainState: state)

        XCTAssertEqual(known, 0)
        XCTAssertEqual(afterFailure, 0)
    }

    func test_restoredPortfolioAfterKnownZero_keepsZero() async {
        for hasCachedAsset in [false, true] {
            let provider = makeProvider(script: .init([.listing([]), .failure]))
            let persistedAssets = [makeAsset(assetId: trxAssetId, balance: 99)]
            if hasCachedAsset {
                provider.primeCache(assets: persistedAssets, multichainState: state)
            }

            let known = await provider.loadBalance(for: trxAssetId, multichainState: state)
            provider.restoreCache(assets: persistedAssets, multichainState: state)
            let afterFailure = await provider.loadBalance(for: trxAssetId, multichainState: state)

            XCTAssertEqual(known, 0)
            XCTAssertEqual(afterFailure, 0)
            if !hasCachedAsset {
                XCTAssertNil(provider.cachedAsset(for: trxAssetId, multichainState: state))
            }
        }
    }

    /// A primed page mentioning the asset outdates the known zero even though `primeCache` leaves
    /// the existing entry alone.
    func test_primedPageAfterKnownZero_dropsTheKnownZero() async {
        let provider = makeProvider(
            script: .init([
                .listing([makeAsset(assetId: "ton/mainnet/coin", balance: 5)]),
                .failure,
            ])
        )
        provider.primeCache(
            assets: [makeAsset(assetId: trxAssetId, balance: 99)],
            multichainState: state
        )

        let known = await provider.loadBalance(for: trxAssetId, multichainState: state)
        provider.primeCache(
            assets: [makeAsset(assetId: trxAssetId, balance: 7)],
            multichainState: state
        )
        let afterFailure = await provider.loadBalance(for: trxAssetId, multichainState: state)

        XCTAssertEqual(known, 0)
        XCTAssertEqual(afterFailure, 99)
    }

    func test_assetReappearingInListing_dropsTheKnownZero() async {
        let provider = makeProvider(
            script: .init([
                .listing([]),
                .listing([makeAsset(assetId: trxAssetId, balance: 7)]),
                .failure,
            ])
        )

        _ = await provider.loadBalance(for: trxAssetId, multichainState: state)
        let reappeared = await provider.loadBalance(for: trxAssetId, multichainState: state)
        let afterFailure = await provider.loadBalance(for: trxAssetId, multichainState: state)

        XCTAssertEqual(reappeared, 7)
        XCTAssertEqual(afterFailure, 7)
    }

    func test_failedListing_fallsBackToCachedBalance() async {
        let provider = makeProvider(assets: .failure)
        provider.primeCache(
            assets: [makeAsset(assetId: trxAssetId, balance: 99)],
            multichainState: state
        )

        let balance = await provider.loadBalance(for: trxAssetId, multichainState: state)

        XCTAssertEqual(balance, 99)
    }

    /// The battery's relayer names a fee token its own way — the address in lowercase, `bnb` for
    /// BSC, another type label — and an exact lookup took a token the wallet holds for one it does not.
    func test_assetsNamedInAnotherSpelling_resolveToTheWalletsBalances() async {
        let ethUSDT = "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"
        let bscUSDT = "bnb/mainnet/token/0x55d398326f99059ff775485246999027b3197955"
        let provider = makeProvider(assets: .listing([
            makeAsset(assetId: "eth/mainnet/erc20/0xdAC17F958D2ee523a2206206994597C13D831ec7", balance: 7_000_000),
            makeAsset(assetId: "bsc/mainnet/bep20/0x55d398326f99059fF775485246999027B3197955", balance: 3_000_000),
        ]))

        let balances = await provider.loadBalances(ofAssetsNamed: [ethUSDT, bscUSDT], wallet: wallet)

        XCTAssertEqual(balances, [ethUSDT: 7_000_000, bscUSDT: 3_000_000])
    }

    /// The wallet's own entry comes back under the name it was asked for, so a caller can go on with
    /// the wallet's id for the asset.
    func test_assetsNamedInAnotherSpelling_resolveToTheWalletsEntries() async {
        let walletUSDT = makeAsset(assetId: "eth/mainnet/erc20/0xdAC17F958D2ee523a2206206994597C13D831ec7", balance: 7_000_000)
        let provider = makeProvider(assets: .listing([walletUSDT]))

        let assets = await provider.loadAssets(named: [usdtAssetId], wallet: wallet)

        XCTAssertEqual(assets, [usdtAssetId: walletUSDT])
    }

    func test_assetsNamedButMissingFromTheListing_haveNoBalance() async {
        let provider = makeProvider(assets: .listing([makeAsset(assetId: "eth/mainnet/coin", balance: 5)]))

        let balances = await provider.loadBalances(ofAssetsNamed: [usdtAssetId], wallet: wallet)

        XCTAssertEqual(balances, [:])
    }

    func test_assetsNamedWithoutAListing_haveNoBalance() async {
        let provider = makeProvider(assets: .failure)

        let balances = await provider.loadBalances(ofAssetsNamed: [usdtAssetId], wallet: wallet)

        XCTAssertEqual(balances, [:])
    }

    /// A wallet can list thousands of assets: the pages after the one that holds the last asset
    /// asked for are not read.
    func test_assetsNamed_stopTheListingOnceAllAreFound() async {
        let usdcAssetId = "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
        let service = MultichainServiceFake(walletAssets: .pages([
            [makeAsset(assetId: usdtAssetId, balance: 7_000_000)],
            [makeAsset(assetId: "eth/mainnet/coin", balance: 5)],
            [makeAsset(assetId: usdcAssetId, balance: 2_000_000)],
            [makeAsset(assetId: "eth/mainnet/erc20/0x6b175474e89094c44da98b954eedeac495271d0f", balance: 1)],
        ]))
        let provider = makeProvider(service: service)

        let balances = await provider.loadBalances(ofAssetsNamed: [usdcAssetId, usdtAssetId], wallet: wallet)

        XCTAssertEqual(balances, [usdtAssetId: 7_000_000, usdcAssetId: 2_000_000])
        XCTAssertEqual(service.requests.assetIds.count, 3)
    }

    func test_assetsNamed_keepWhatTheListingFoundBeforeItFailed() async {
        let usdcAssetId = "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
        let provider = makeProvider(script: .init([
            .pages([
                [makeAsset(assetId: usdtAssetId, balance: 7_000_000)],
                [makeAsset(assetId: usdcAssetId, balance: 2_000_000)],
            ]),
            .failure,
        ]))

        let balances = await provider.loadBalances(ofAssetsNamed: [usdcAssetId, usdtAssetId], wallet: wallet)

        XCTAssertEqual(balances, [usdtAssetId: 7_000_000])
    }

    func test_nothingNamed_readsNothing() async {
        let service = MultichainServiceFake(walletAssets: .listing([]))
        let provider = makeProvider(service: service)

        let balances = await provider.loadBalances(ofAssetsNamed: [], wallet: wallet)

        XCTAssertEqual(balances, [:])
        XCTAssertTrue(service.requests.assetIds.isEmpty)
    }
}

private extension MultichainAssetBalanceProviderLoadBalanceTests {
    func makeProvider(
        assets: MultichainServiceFake.WalletAssets = .failure,
        script: MultichainServiceFake.WalletAssetsScript? = nil
    ) -> MultichainAssetBalanceProvider {
        makeProvider(service: MultichainServiceFake(walletAssets: assets, walletAssetsScript: script))
    }

    func makeProvider(service: MultichainServiceFake) -> MultichainAssetBalanceProvider {
        MultichainAssetBalanceProvider(
            balanceService: service,
            currencyStore: CurrencyStore(
                keeperInfoStore: KeeperInfoStore(
                    keeperInfoRepository: LoadBalanceKeeperInfoRepositoryFake()
                )
            )
        )
    }

    var wallet: Wallet {
        Wallet(
            id: "wallet-id",
            identity: .init(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
            ),
            metaData: .init(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(state)
        )
    }

    func makeAsset(assetId: String, balance: BigUInt) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                chain: .tron,
                name: "TRON",
                symbol: "TRX",
                decimals: 6,
                image: ""
            ),
            price: MultichainAssetPrice(
                prices: [:],
                diff24h: [:],
                diff7d: [:]
            ),
            isHidden: false,
            balance: balance
        )
    }
}

private struct LoadBalanceKeeperInfoRepositoryFake: KeeperInfoRepository {
    func getKeeperInfo() throws -> KeeperInfo {
        throw NSError(domain: "LoadBalanceKeeperInfoRepositoryFake", code: 0)
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}
