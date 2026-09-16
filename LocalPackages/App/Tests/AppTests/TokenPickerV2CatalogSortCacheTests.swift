@testable import App
import BigInt
@testable import KeeperCore
import XCTest

@MainActor
final class TokenPickerV2CatalogSortCacheTests: XCTestCase {
    func test_changingSortInvalidatesInactiveChainTabCache() async {
        let model = CatalogSortTrackingModel()
        let viewModel = TokenPickerV2ViewModelImplementation(
            headerTitle: "Crypto",
            tokenPickerModel: model,
            amountFormatter: FormattersAssembly().amountFormatter,
            currencyStore: makeCurrencyStore()
        )

        viewModel.viewDidLoad()
        await waitUntilLoaded(viewModel)
        XCTAssertEqual(model.sortsRequested(for: .all), [.marketCap])

        viewModel.selectChainFilter(.chain(.eth))
        await waitUntilLoaded(viewModel)
        XCTAssertEqual(model.sortsRequested(for: .chain(.eth)), [.marketCap])

        viewModel.selectCatalogSort(.volume)
        await waitUntilLoaded(viewModel)
        XCTAssertEqual(viewModel.catalogSearchSort, .volume)
        XCTAssertEqual(model.sortsRequested(for: .chain(.eth)), [.marketCap, .volume])

        viewModel.selectChainFilter(.all)
        await waitUntilLoaded(viewModel)

        XCTAssertEqual(
            model.sortsRequested(for: .all),
            [.marketCap, .volume],
            "All tab must refetch with the new sort instead of reusing the market-cap cache"
        )
        XCTAssertEqual(viewModel.catalogSearchSort, .volume)
    }

    func test_priceDiffSortsInvalidateCachedQueries() async {
        let model = CatalogSortTrackingModel()
        let viewModel = TokenPickerV2ViewModelImplementation(
            headerTitle: "Crypto",
            tokenPickerModel: model,
            amountFormatter: FormattersAssembly().amountFormatter,
            currencyStore: makeCurrencyStore()
        )

        viewModel.viewDidLoad()
        await waitUntilLoaded(viewModel)

        viewModel.selectCatalogSort(.priceDiffAsc)
        await waitUntilLoaded(viewModel)
        XCTAssertEqual(model.sortsRequested(for: .all), [.marketCap, .priceDiffAsc])

        viewModel.selectChainFilter(.chain(.eth))
        await waitUntilLoaded(viewModel)
        XCTAssertEqual(model.sortsRequested(for: .chain(.eth)), [.priceDiffAsc])

        viewModel.selectCatalogSort(.priceDiffDesc)
        await waitUntilLoaded(viewModel)
        XCTAssertEqual(
            model.sortsRequested(for: .chain(.eth)),
            [.priceDiffAsc, .priceDiffDesc]
        )

        viewModel.selectChainFilter(.all)
        await waitUntilLoaded(viewModel)
        XCTAssertEqual(
            model.sortsRequested(for: .all),
            [.marketCap, .priceDiffAsc, .priceDiffDesc]
        )
    }

    func test_waitingForSelectionCompletionKeepsPickerOpenAndBlocksRepeatedSelection() async throws {
        let model = CatalogSortTrackingModel()
        let viewModel = TokenPickerV2ViewModelImplementation(
            headerTitle: "Crypto",
            tokenPickerModel: model,
            amountFormatter: FormattersAssembly().amountFormatter,
            currencyStore: makeCurrencyStore(),
            waitsForSelectionCompletion: true
        )
        var selectionCount = 0
        var finishCount = 0
        viewModel.didSelectAsset = { _ in
            selectionCount += 1
        }
        viewModel.didFinish = {
            finishCount += 1
        }

        viewModel.viewDidLoad()
        await waitUntilLoaded(viewModel)
        let id = try XCTUnwrap(viewModel.currentQueryViewModel?.presentation.items.first?.id)

        viewModel.selectRow(id)
        viewModel.selectRow(id)

        XCTAssertEqual(selectionCount, 1)
        XCTAssertTrue(viewModel.isAwaitingAssetSelection)

        viewModel.finishAssetSelection(shouldClose: false)

        XCTAssertEqual(finishCount, 0)
        XCTAssertFalse(viewModel.isAwaitingAssetSelection)

        viewModel.selectRow(id)
        viewModel.finishAssetSelection(shouldClose: true)

        XCTAssertEqual(selectionCount, 2)
        XCTAssertEqual(finishCount, 1)
    }
}

@MainActor
private extension TokenPickerV2CatalogSortCacheTests {
    func waitUntilLoaded(
        _ viewModel: TokenPickerV2ViewModelImplementation,
        timeoutNanoseconds: UInt64 = 2_000_000_000
    ) async {
        let deadline = DispatchTime.now() + .nanoseconds(Int(timeoutNanoseconds))
        while DispatchTime.now() < deadline {
            if case .loaded = viewModel.currentQueryViewModel?.state {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for TokenPickerV2 query to load")
    }

    func makeCurrencyStore() -> CurrencyStore {
        CurrencyStore(
            keeperInfoStore: KeeperInfoStore(
                keeperInfoRepository: KeeperInfoRepositoryStub(keeperInfo: nil)
            )
        )
    }
}

private final class CatalogSortTrackingModel: TokenPickerV2Model {
    private(set) var catalogSearchSort: MultichainAssetSearchSort = .marketCap
    let showsCatalogSortControl = true

    let initialState = TokenPickerV2ModelState(
        filters: [.all, .chain(.eth)],
        displayMode: .includingMarketData,
        initialFilter: .all
    )

    private var recordedSorts = [TokenPickerV2ChainFilter: [MultichainAssetSearchSort]]()

    func sortsRequested(for filter: TokenPickerV2ChainFilter) -> [MultichainAssetSearchSort] {
        recordedSorts[filter] ?? []
    }

    func setCatalogSearchSort(_ sort: MultichainAssetSearchSort) {
        catalogSearchSort = sort
    }

    func loadAssets(
        query _: String?,
        filter: TokenPickerV2ChainFilter,
        limit _: Int,
        cursor _: String?
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        recordedSorts[filter, default: []].append(catalogSearchSort)
        return TokenPickerLoadResult(
            assets: [
                MultichainAsset(
                    asset: MultichainAssetDetails(
                        assetId: "eth/mainnet/coin",
                        name: "Ethereum",
                        symbol: "ETH",
                        decimals: 18,
                        image: "",
                        verification: .whitelist
                    ),
                    price: MultichainAssetPrice(
                        prices: [:],
                        diff24h: [:],
                        diff7d: [:],
                        diff30d: [:]
                    ),
                    balance: BigUInt(0)
                ),
            ],
            nextCursor: nil
        )
    }
}

private final class KeeperInfoRepositoryStub: KeeperInfoRepository {
    enum Error: Swift.Error {
        case noKeeperInfo
    }

    var keeperInfo: KeeperInfo?

    init(keeperInfo: KeeperInfo?) {
        self.keeperInfo = keeperInfo
    }

    func getKeeperInfo() throws -> KeeperInfo {
        guard let keeperInfo else {
            throw Error.noKeeperInfo
        }
        return keeperInfo
    }

    func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {
        self.keeperInfo = keeperInfo
    }

    func removeKeeperInfo() throws {
        self.keeperInfo = nil
    }
}
