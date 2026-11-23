@testable import App
import BigInt
@testable import KeeperCore
import PerpsModels
import TKCore
import XCTest

final class TokenPickerV2ChainFilterTests: XCTestCase {
    @MainActor
    func test_selectChainFilter_keepsSearchTextAndScopesQueryToFilter() async {
        let model = TokenPickerV2ModelSpy()
        let viewModel = makeViewModel(model: model)
        viewModel.viewDidLoad()
        viewModel.search(text: "app")

        viewModel.selectChainFilter(.chain(.eth))
        await viewModel.loadFiltersTask?.value

        XCTAssertEqual(viewModel.searchText, "app")

        await viewModel.currentQueryViewModel?.refresh()

        XCTAssertEqual(model.requests.last?.query, "app")
        XCTAssertEqual(model.requests.last?.filter, .chain(.eth))
    }

    @MainActor
    func test_selectChainFilter_withoutSearchTextLoadsWholeFilter() async {
        let model = TokenPickerV2ModelSpy()
        let viewModel = makeViewModel(model: model)
        viewModel.viewDidLoad()

        viewModel.selectChainFilter(.chain(.eth))
        await viewModel.loadFiltersTask?.value

        await viewModel.currentQueryViewModel?.refresh()

        XCTAssertNil(model.requests.last?.query)
        XCTAssertEqual(model.requests.last?.filter, .chain(.eth))
    }

    @MainActor
    func test_cancelledAssetTypeResponseDoesNotReplaceCurrentChainTabs() async throws {
        let model = TokenPickerV2ModelSpy()
        let viewModel = makeViewModel(model: model)
        viewModel.viewDidLoad()
        await viewModel.loadFiltersTask?.value
        await viewModel.currentQueryViewModel?.refresh()

        let suspended = expectation(description: "Previous query suspended")
        model.onLoadSuspended = { suspended.fulfill() }
        model.suspendNextLoad = true
        let oldQuery = try XCTUnwrap(viewModel.currentQueryViewModel)
        let refreshTask = Task { await oldQuery.refresh() }
        await fulfillment(of: [suspended], timeout: 2)
        let pendingLoad = try XCTUnwrap(model.pendingLoad)

        model.result = TokenPickerLoadResult(items: [], nextCursor: nil, filters: [.all, .chain(.ton)])
        viewModel.selectAssetType(.category(.stocks))
        await viewModel.currentQueryViewModel?.refresh()
        XCTAssertEqual(viewModel.tabs.map(\.id), [.all, .chain(.ton)])

        pendingLoad.resume(returning: TokenPickerLoadResult(items: [], nextCursor: nil, filters: [.all, .chain(.eth)]))
        await refreshTask.value
        XCTAssertEqual(viewModel.tabs.map(\.id), [.all, .chain(.ton)])
    }

    @MainActor
    func test_catalogChainMenuShowsOnlyLoadedChainsPerAssetType() async {
        let model = TokenPickerV2ModelSpy()
        model.assetTypes = [.category(.all), .category(.stocks)]
        model.result = TokenPickerLoadResult(items: [], nextCursor: nil, filters: [.all, .chain(.eth)])
        let viewModel = makeViewModel(model: model)

        viewModel.viewDidLoad()
        XCTAssertEqual(viewModel.tabs.map(\.id), [.all])
        await waitUntilLoaded(viewModel)
        XCTAssertEqual(viewModel.tabs.map(\.id), [.all, .chain(.eth)])

        model.result = TokenPickerLoadResult(items: [], nextCursor: nil, filters: [.all, .chain(.ton)])
        viewModel.selectAssetType(.category(.stocks))
        XCTAssertEqual(viewModel.tabs.map(\.id), [.all])
        await waitUntilLoaded(viewModel)
        XCTAssertEqual(viewModel.tabs.map(\.id), [.all, .chain(.ton)])

        viewModel.selectAssetType(.category(.all))
        XCTAssertEqual(viewModel.tabs.map(\.id), [.all, .chain(.eth)])
    }

    @MainActor
    func test_returningToAssetTypeReusesItsLoadedList() async {
        let model = TokenPickerV2ModelSpy()
        model.result = oneAssetResult
        let viewModel = makeViewModel(model: model)
        viewModel.viewDidLoad()
        await waitUntilLoaded(viewModel)

        viewModel.selectAssetType(.category(.stocks))
        await waitUntilLoaded(viewModel)
        viewModel.selectAssetType(.category(.all))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(model.requests.map(\.assetType), [.category(.all), .category(.stocks)])
        XCTAssertEqual(viewModel.currentQueryViewModel?.presentation.showsSkeleton, false)
    }

    @MainActor
    func test_perpsSortChangeKeepsCatalogListCached() async {
        let model = TokenPickerV2ModelSpy()
        model.result = oneAssetResult
        let viewModel = makeViewModel(model: model)
        viewModel.viewDidLoad()
        await waitUntilLoaded(viewModel)

        viewModel.selectAssetType(.perpetuals)
        await waitUntilLoaded(viewModel)
        viewModel.selectPerpsSort(.priceChange)
        await waitUntilLoaded(viewModel)
        viewModel.selectAssetType(.category(.all))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(model.requests.map(\.assetType), [.category(.all), .perpetuals, .perpetuals])
    }

    @MainActor
    func test_chipResettingChainDropsPendingSearchForOldChain() async {
        let model = TokenPickerV2ModelSpy()
        model.assetTypes = [.category(.all), .category(.stocks)]
        model.resultsByAssetType = [
            .category(.all): TokenPickerLoadResult(items: [], nextCursor: nil, filters: [.all, .chain(.eth)]),
            .category(.stocks): TokenPickerLoadResult(items: [], nextCursor: nil, filters: [.all, .chain(.ton)]),
        ]
        let viewModel = makeViewModel(model: model)
        viewModel.viewDidLoad()
        await waitUntilLoaded(viewModel)
        viewModel.selectAssetType(.category(.stocks))
        await waitUntilLoaded(viewModel)
        viewModel.selectAssetType(.category(.all))
        viewModel.selectChainFilter(.chain(.eth))
        await waitUntilLoaded(viewModel)

        viewModel.search(text: "btc")
        viewModel.selectAssetType(.category(.stocks))
        try? await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(viewModel.selectedChainFilter, .all)
        XCTAssertEqual(model.requests.last, .init(query: "btc", filter: .all, assetType: .category(.stocks)))
        XCTAssertFalse(model.requests.contains { $0.query == "btc" && $0.filter == .chain(.eth) })
    }

    @MainActor
    func test_chipAnsweredWithoutChainsKeepsWalletChainsAfterChipSwitch() async {
        let model = TokenPickerV2ModelSpy()
        model.assetTypes = [.category(.all), .category(.stocks)]
        model.resultsByAssetType = [
            .category(.all): oneAssetResult,
            .category(.stocks): TokenPickerLoadResult(items: [], nextCursor: nil, filters: [.all, .chain(.ton)]),
        ]
        let viewModel = makeViewModel(model: model)
        viewModel.viewDidLoad()
        await waitUntilLoaded(viewModel)
        XCTAssertEqual(viewModel.tabs.map(\.id), [.all, .chain(.ton), .chain(.eth)])

        viewModel.selectAssetType(.category(.stocks))
        await waitUntilLoaded(viewModel)
        viewModel.selectAssetType(.category(.all))

        XCTAssertEqual(viewModel.tabs.map(\.id), [.all, .chain(.ton), .chain(.eth)])
    }

    @MainActor
    func test_failedListReloadsAfterMarketChipSwitch() async {
        let model = TokenPickerV2ModelSpy()
        model.result = oneAssetResult
        model.failsNextLoad = true
        let viewModel = makeViewModel(model: model)
        viewModel.viewDidLoad()
        await viewModel.loadFiltersTask?.value
        try? await Task.sleep(nanoseconds: 50_000_000)
        guard case .failed = viewModel.currentQueryViewModel?.state else {
            return XCTFail("Expected the first load to fail")
        }

        viewModel.selectAssetType(.category(.stocks))
        await waitUntilLoaded(viewModel)
        viewModel.selectAssetType(.category(.all))
        await waitUntilLoaded(viewModel)

        XCTAssertEqual(model.requests.map(\.assetType), [.category(.all), .category(.stocks), .category(.all)])
    }

    @MainActor
    func test_currencyChangeDropsCachedLists() async {
        let model = TokenPickerV2ModelSpy()
        model.result = oneAssetResult
        let currencyStore = makeCurrencyStore()
        let viewModel = makeViewModel(model: model, currencyStore: currencyStore)
        viewModel.viewDidLoad()
        await waitUntilLoaded(viewModel)

        viewModel.appeared()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(model.requests.count, 1)

        await withCheckedContinuation { continuation in
            currencyStore.updateState {
                _ in .init(newState: .BTC)
            } completion: {
                _ in continuation.resume()
            }
        }
        viewModel.appeared()
        await waitUntilLoaded(viewModel)

        XCTAssertEqual(model.requests.count, 2)
    }

    func test_walletFilters_followDisplayOrderNotAddressOrder() {
        let state = MultichainWalletState(
            walletId: "wallet",
            addresses: [.ton, .eth, .base, .btc, .tron, .arb, .bsc, .ton].map {
                MultichainWalletAddress(chain: $0, address: $0.rawValue)
            }
        )

        XCTAssertEqual(
            state.tokenPickerV2Filters,
            [.all, .chain(.ton), .chain(.eth), .chain(.bsc), .chain(.tron), .chain(.arb), .chain(.btc), .chain(.base)]
        )
    }
}

private extension TokenPickerV2ChainFilterTests {
    var oneAssetResult: TokenPickerLoadResult {
        TokenPickerLoadResult(
            assets: [
                MultichainAsset(
                    asset: MultichainAssetDetails(
                        assetId: "ton/mainnet/coin",
                        name: "Toncoin",
                        symbol: "TON",
                        decimals: 9,
                        image: "",
                        verification: .trusted
                    ),
                    price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]),
                    balance: BigUInt(0)
                ),
            ],
            nextCursor: nil
        )
    }

    @MainActor
    func waitUntilLoaded(_ viewModel: TokenPickerV2ViewModelImplementation) async {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
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
                keeperInfoRepository: KeeperInfoRepositoryStub()
            )
        )
    }

    @MainActor
    func makeViewModel(
        model: TokenPickerV2ModelSpy,
        currencyStore: CurrencyStore? = nil
    ) -> TokenPickerV2ViewModelImplementation {
        TokenPickerV2ViewModelImplementation(
            headerTitle: "",
            tokenPickerModel: model,
            amountFormatter: FormattersAssembly().amountFormatter,
            currencyStore: currencyStore ?? makeCurrencyStore()
        )
    }
}

private final class TokenPickerV2ModelSpy: TokenPickerV2Model {
    struct Request: Equatable {
        let query: String?
        let filter: TokenPickerV2ChainFilter
        let assetType: TokenPickerV2AssetType
    }

    private(set) var requests = [Request]()
    var result = TokenPickerLoadResult(items: [], nextCursor: nil)
    var resultsByAssetType = [TokenPickerV2AssetType: TokenPickerLoadResult]()
    var failsNextLoad = false
    var suspendNextLoad = false
    var pendingLoad: CheckedContinuation<TokenPickerLoadResult, Never>?
    var onLoadSuspended: (() -> Void)?
    var assetType: TokenPickerV2AssetType = .category(.all)
    var assetTypes = [TokenPickerV2AssetType]()

    func setAssetType(_ assetType: TokenPickerV2AssetType) {
        self.assetType = assetType
    }

    var showsCatalogSortControl: Bool {
        false
    }

    private(set) var catalogSearchSort: MultichainAssetSearchSort = .marketCap
    private(set) var perpsSearchSort: PerpsMarketsSort = .volume

    func setPerpsSearchSort(_ sort: PerpsMarketsSort) {
        perpsSearchSort = sort
    }

    let initialState = TokenPickerV2ModelState(
        filters: [.all, .chain(.ton), .chain(.eth)],
        displayMode: .includingMarketData,
        initialFilter: .all
    )

    func loadAssets(
        query: String?,
        filter: TokenPickerV2ChainFilter,
        limit _: Int,
        cursor _: String?
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        requests.append(Request(query: query, filter: filter, assetType: assetType))
        if failsNextLoad {
            failsNextLoad = false
            throw .apiError(message: nil)
        }
        if suspendNextLoad {
            suspendNextLoad = false
            return await withCheckedContinuation {
                pendingLoad = $0
                onLoadSuspended?()
            }
        }
        return resultsByAssetType[assetType] ?? result
    }

    func setCatalogSearchSort(_ sort: MultichainAssetSearchSort) {
        catalogSearchSort = sort
    }
}

private final class KeeperInfoRepositoryStub: KeeperInfoRepository {
    enum Error: Swift.Error {
        case noKeeperInfo
    }

    private var keeperInfo: KeeperInfo?

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
        keeperInfo = nil
    }
}
