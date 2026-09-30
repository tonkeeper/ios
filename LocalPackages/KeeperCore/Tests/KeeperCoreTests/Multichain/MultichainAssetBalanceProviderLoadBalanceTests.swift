import BigInt
@testable import KeeperCore
import XCTest

final class MultichainAssetBalanceProviderLoadBalanceTests: XCTestCase {
    private let state = MultichainWalletState(walletId: "wallet-id", addresses: [])
    private let trxAssetId = "tron/mainnet/coin"

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
}

private extension MultichainAssetBalanceProviderLoadBalanceTests {
    func makeProvider(
        assets: MultichainServiceFake.WalletAssets = .failure,
        script: MultichainServiceFake.WalletAssetsScript? = nil
    ) -> MultichainAssetBalanceProvider {
        MultichainAssetBalanceProvider(
            balanceService: MultichainServiceFake(
                walletAssets: assets,
                walletAssetsScript: script
            ),
            currencyStore: CurrencyStore(
                keeperInfoStore: KeeperInfoStore(
                    keeperInfoRepository: LoadBalanceKeeperInfoRepositoryFake()
                )
            )
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
                diff7d: [:],
                diff30d: [:]
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
