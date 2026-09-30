import BigInt
@testable import KeeperCore
import XCTest

final class MultichainAssetBalanceProviderPrimeCacheTests: XCTestCase {
    private let state = MultichainWalletState(walletId: "wallet-id", addresses: [])
    private let assetId = "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"

    func test_primedAsset_isReadableWithoutLoading() {
        let provider = makeProvider()

        provider.primeCache(
            assets: [makeAsset(balance: 7_180_000)],
            multichainState: state
        )

        let cached = provider.cachedAsset(for: assetId, multichainState: state)
        XCTAssertEqual(cached?.balance, 7_180_000)
    }

    func test_restoredAsset_isReadableWithoutLoading() {
        let provider = makeProvider()

        provider.restoreCache(assets: [makeAsset(balance: 7_180_000)], multichainState: state)

        XCTAssertEqual(provider.cachedAsset(for: assetId, multichainState: state)?.balance, 7_180_000)
    }

    func test_restoreCache_doesNotOverwriteKnownAssetOrVisibility() {
        let provider = makeProvider()
        provider.primeCache(assets: [makeAsset(balance: 500, isHidden: true)], multichainState: state)

        provider.restoreCache(assets: [makeAsset(balance: 1)], multichainState: state)

        let cached = provider.cachedAsset(for: assetId, multichainState: state)
        XCTAssertEqual(cached?.balance, 500)
        XCTAssertEqual(cached?.isHidden, true)
    }

    func test_primeCache_doesNotOverwriteKnownAsset() {
        let provider = makeProvider()

        provider.primeCache(assets: [makeAsset(balance: 500)], multichainState: state)
        provider.primeCache(assets: [makeAsset(balance: 1)], multichainState: state)

        let cached = provider.cachedAsset(for: assetId, multichainState: state)
        XCTAssertEqual(cached?.balance, 500)
    }

    func test_primeCache_keepsScopesApart() {
        let provider = makeProvider()
        let otherState = MultichainWalletState(walletId: "wallet-id", addresses: [
            MultichainWalletAddress(chain: .tron, address: "TOther"),
        ])

        provider.primeCache(assets: [makeAsset(balance: 42)], multichainState: state)

        XCTAssertNil(provider.cachedAsset(for: assetId, multichainState: otherState))
    }

    func test_primedHiddenAsset_isFilteredWhenHiddenExcluded() {
        let provider = makeProvider()

        provider.primeCache(
            assets: [makeAsset(balance: 42, isHidden: true)],
            multichainState: state
        )

        XCTAssertNil(
            provider.cachedAsset(
                for: assetId,
                multichainState: state,
                includingHidden: false
            )
        )
        XCTAssertNotNil(
            provider.cachedAsset(
                for: assetId,
                multichainState: state,
                includingHidden: true
            )
        )
    }
}

private extension MultichainAssetBalanceProviderPrimeCacheTests {
    func makeProvider() -> MultichainAssetBalanceProvider {
        MultichainAssetBalanceProvider(
            balanceService: MultichainServiceFake(),
            currencyStore: CurrencyStore(
                keeperInfoStore: KeeperInfoStore(
                    keeperInfoRepository: PrimeCacheKeeperInfoRepositoryFake()
                )
            )
        )
    }

    func makeAsset(balance: BigUInt, isHidden: Bool = false) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                chain: .tron,
                name: "USDT",
                symbol: "USDT",
                decimals: 6,
                image: ""
            ),
            price: MultichainAssetPrice(
                prices: [:],
                diff24h: [:],
                diff7d: [:],
                diff30d: [:]
            ),
            isHidden: isHidden,
            balance: balance
        )
    }
}

private struct PrimeCacheKeeperInfoRepositoryFake: KeeperInfoRepository {
    func getKeeperInfo() throws -> KeeperInfo {
        throw NSError(domain: "PrimeCacheKeeperInfoRepositoryFake", code: 0)
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}
