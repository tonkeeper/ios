@testable import App
@testable import KeeperCore
import TKCore
import TKLocalize
import XCTest

final class TradeAssetsListViewModelTests: XCTestCase {
    @MainActor
    func test_updateSearchText_debouncesActivationAndLoadsOnlyFinalQuery() async {
        let service = TradingAssetsListServiceSpy()
        await service.setLoadPlans([
            .success(
                snapshot(
                    ids: ["ton"],
                    nextCursor: nil
                ),
                delayNanoseconds: 1_000_000_000
            ),
            .success(
                snapshot(
                    ids: ["btc"],
                    nextCursor: nil
                )
            ),
        ])

        let viewModel = makeViewModel(assetsListService: service)

        viewModel.loadIfNeeded()
        await waitUntil {
            await service.loadRequests().count == 1
        }

        viewModel.updateSearchText("b")
        viewModel.updateSearchText("bt")
        viewModel.updateSearchText("btc")

        try? await Task.sleep(nanoseconds: 100_000_000)
        let requestsBeforeDebounce = await service.loadRequests()
        XCTAssertEqual(requestsBeforeDebounce.count, 1)

        await waitUntil {
            await service.loadRequests().count == 2
        }

        let loadRequests = await service.loadRequests()
        XCTAssertEqual(loadRequests.last, .init(query: "btc", category: .all))
        XCTAssertFalse(loadRequests.contains(.init(query: "b", category: .all)))
        XCTAssertFalse(loadRequests.contains(.init(query: "bt", category: .all)))

        await waitUntil {
            await MainActor.run {
                self.currentAssets(in: viewModel.currentQueryViewModel).map(\.id) == ["btc"]
            }
        }
    }

    @MainActor
    func test_selectCategory_preservesSearchTextAndSwitchesToIndependentCategoryViewModel() async {
        let service = TradingAssetsListServiceSpy()
        await service.setLoadPlans([
            .success(
                snapshot(
                    ids: ["ton"],
                    nextCursor: nil
                )
            ),
            .success(
                snapshot(
                    ids: ["aaplx"],
                    nextCursor: nil
                )
            ),
            .success(
                snapshot(
                    ids: ["ton-search"],
                    nextCursor: nil
                )
            ),
        ])

        let viewModel = makeViewModel(assetsListService: service)

        viewModel.loadIfNeeded()
        await waitUntil {
            await service.loadRequests().count == 1
        }

        viewModel.updateSearchText("ton")
        viewModel.selectCategory(.stocks)

        XCTAssertEqual(viewModel.searchText, "ton")

        await waitUntil {
            await service.loadRequests().count == 2
        }

        let loadRequests = await service.loadRequests()
        XCTAssertEqual(loadRequests.last, .init(query: "ton", category: .stocks))
        XCTAssertFalse(loadRequests.contains(.init(query: "ton", category: .all)))

        await waitUntil {
            await MainActor.run {
                self.currentAssets(in: viewModel.currentQueryViewModel).map(\.id) == ["aaplx"]
            }
        }

        viewModel.selectCategory(.all)

        await waitUntil {
            await service.loadRequests().count == 3
        }
        let requestsAfterSwitchingBack = await service.loadRequests()
        XCTAssertEqual(
            requestsAfterSwitchingBack.filter { $0 == .init(query: nil, category: .all) }.count,
            1
        )
        XCTAssertEqual(requestsAfterSwitchingBack.last, .init(query: "ton", category: .all))

        XCTAssertEqual(viewModel.searchText, "ton")
        XCTAssertEqual(currentAssets(in: viewModel.currentQueryViewModel).map(\.id), ["ton-search"])
    }

    @MainActor
    func test_loadNextPageIfNeeded_doesNotPaginateWhenAssetIsOutsideThreshold() async {
        let service = TradingAssetsListServiceSpy()
        await service.setLoadPlans([
            .success(
                snapshot(
                    ids: ["1", "2", "3", "4", "5", "6"],
                    nextCursor: "cursor-2"
                )
            ),
        ])
        await service.setLoadNextPagePlans([
            .success(
                snapshot(
                    ids: ["7"],
                    nextCursor: nil
                )
            ),
        ])

        let viewModel = makeViewModel(assetsListService: service)

        viewModel.loadIfNeeded()
        await waitUntil {
            await MainActor.run {
                self.currentAssets(in: viewModel.currentQueryViewModel).count == 6
            }
        }

        let firstAsset = try? XCTUnwrap(currentAssets(in: viewModel.currentQueryViewModel).first)
        guard let firstAsset else {
            return XCTFail("Expected loaded asset")
        }

        viewModel.loadNextPageIfNeeded(currentAsset: firstAsset)

        try? await Task.sleep(nanoseconds: 50_000_000)
        let loadNextPageRequests = await service.loadNextPageRequests()
        XCTAssertTrue(loadNextPageRequests.isEmpty)
    }

    @MainActor
    func test_loadNextPageIfNeeded_ignoresRepeatedTriggerWhilePaginationIsRunning() async {
        let service = TradingAssetsListServiceSpy()
        await service.setLoadPlans([
            .success(
                snapshot(
                    ids: ["1", "2", "3", "4", "5", "6"],
                    nextCursor: "cursor-2"
                )
            ),
        ])
        await service.setLoadNextPagePlans([
            .success(
                snapshot(
                    ids: ["7"],
                    nextCursor: nil
                ),
                delayNanoseconds: 500_000_000
            ),
        ])

        let viewModel = makeViewModel(assetsListService: service)

        viewModel.loadIfNeeded()
        await waitUntil {
            await MainActor.run {
                self.currentAssets(in: viewModel.currentQueryViewModel).count == 6
            }
        }

        let lastAsset = try? XCTUnwrap(currentAssets(in: viewModel.currentQueryViewModel).last)
        guard let lastAsset else {
            return XCTFail("Expected loaded asset")
        }

        viewModel.loadNextPageIfNeeded(currentAsset: lastAsset)
        viewModel.loadNextPageIfNeeded(currentAsset: lastAsset)

        try? await Task.sleep(nanoseconds: 50_000_000)
        let loadNextPageRequests = await service.loadNextPageRequests()
        XCTAssertEqual(loadNextPageRequests.count, 1)

        await waitUntil {
            await MainActor.run {
                self.currentAssets(in: viewModel.currentQueryViewModel).map(\.id) == ["1", "2", "3", "4", "5", "6", "7"]
            }
        }
    }

    @MainActor
    func test_contentViewModel_keepsStableInstancesForInactiveCategories() async {
        let service = TradingAssetsListServiceSpy()
        await service.setLoadPlans([
            .success(
                snapshot(
                    ids: ["ton"],
                    nextCursor: nil
                )
            ),
            .success(
                snapshot(
                    ids: ["aaplx"],
                    nextCursor: nil
                )
            ),
        ])
        let viewModel = makeViewModel(assetsListService: service)

        viewModel.loadIfNeeded()
        await waitUntil {
            await service.loadRequests().count == 1
        }

        let allContentViewModel = viewModel.contentViewModel(for: .all)
        let stocksContentViewModel = viewModel.contentViewModel(for: .stocks)

        viewModel.selectCategory(.stocks)

        await waitUntil {
            await service.loadRequests().count == 2
        }

        XCTAssertTrue(viewModel.contentViewModel(for: .all) === allContentViewModel)
        XCTAssertTrue(viewModel.contentViewModel(for: .stocks) === viewModel.currentQueryViewModel)
        XCTAssertTrue(viewModel.contentViewModel(for: .stocks) === stocksContentViewModel)

        viewModel.selectCategory(.all)

        XCTAssertTrue(viewModel.contentViewModel(for: .all) === allContentViewModel)
        XCTAssertTrue(viewModel.contentViewModel(for: .stocks) === stocksContentViewModel)
    }

    @MainActor
    func test_refresh_failure_keepsPreviouslyLoadedAssets() async {
        let service = TradingAssetsListServiceSpy()
        await service.setLoadPlans([
            .success(
                snapshot(
                    ids: ["ton"],
                    nextCursor: nil
                )
            ),
            .failure(.networkError),
        ])

        let viewModel = makeViewModel(assetsListService: service)

        viewModel.loadIfNeeded()
        await waitUntil {
            await MainActor.run {
                self.currentAssets(in: viewModel.currentQueryViewModel).map(\.id) == ["ton"]
            }
        }

        await viewModel.refresh()

        XCTAssertEqual(currentAssets(in: viewModel.currentQueryViewModel).map(\.id), ["ton"])
        XCTAssertEqual(currentStateMessage(in: viewModel.currentQueryViewModel), TKLocales.ConnectionStatus.noInternet)
    }

    @MainActor
    func test_refresh_waitsForLoadTaskCompletion() async {
        let service = TradingAssetsListServiceSpy()
        await service.setLoadPlans([
            .success(
                snapshot(
                    ids: ["ton"],
                    nextCursor: nil
                )
            ),
            .success(
                snapshot(
                    ids: ["btc"],
                    nextCursor: nil
                ),
                delayNanoseconds: 300_000_000
            ),
        ])

        let viewModel = makeViewModel(assetsListService: service)
        let probe = CompletionProbe()

        viewModel.loadIfNeeded()
        await waitUntil {
            await MainActor.run {
                self.currentAssets(in: viewModel.currentQueryViewModel).map(\.id) == ["ton"]
            }
        }

        Task {
            await viewModel.refresh()
            await probe.markCompleted()
        }

        try? await Task.sleep(nanoseconds: 50_000_000)
        let isCompletedEarly = await probe.isCompleted()
        XCTAssertFalse(isCompletedEarly)
        XCTAssertTrue(isRefreshing(viewModel.currentQueryViewModel))

        await waitUntil {
            await probe.isCompleted()
        }

        XCTAssertEqual(currentAssets(in: viewModel.currentQueryViewModel).map(\.id), ["btc"])
    }

    @MainActor
    func test_openAsset_usesAssetCategoryForAllTab() async {
        let service = TradingAssetsListServiceSpy()
        await service.setLoadPlans([
            .success(
                snapshot(
                    ids: ["ton/mainnet/stocks/0:abcdef"],
                    category: .stocks,
                    nextCursor: nil
                )
            ),
        ])

        var openedCategory: TradingAssetCategory?
        let viewModel = makeViewModel(
            assetsListService: service,
            onOpenAssetDetails: { asset in
                openedCategory = asset.category
            }
        )

        viewModel.loadIfNeeded()
        await waitUntil {
            await MainActor.run {
                self.currentAssets(in: viewModel.currentQueryViewModel).count == 1
            }
        }

        let asset = try? XCTUnwrap(currentAssets(in: viewModel.currentQueryViewModel).first)
        guard let asset else {
            return XCTFail("Expected loaded asset")
        }

        viewModel.openAsset(asset)

        XCTAssertEqual(openedCategory, .stocks)
    }

    @MainActor
    func test_cellConfig_setsVerificationCheckmarkOnlyForTrustedAssets() {
        let formattersAssembly = FormattersAssembly()
        let queryViewModel = TradeAssetsListQueryViewModel(
            query: nil,
            category: .all,
            assetsListService: TradingAssetsListServiceSpy(),
            amountFormatter: formattersAssembly.amountFormatter,
            signedAmountFormatter: formattersAssembly.signedAmountFormatter,
            onWillPerformSearch: {}
        )

        let trustedConfig = queryViewModel.cellConfig(
            for: tradingAsset(id: "trusted", verification: .trusted),
            currency: .USD
        )
        let whitelistConfig = queryViewModel.cellConfig(
            for: tradingAsset(id: "whitelist", verification: .whitelist),
            currency: .USD
        )
        let unverifiedConfig = queryViewModel.cellConfig(
            for: tradingAsset(id: "unverified", verification: .none),
            currency: .USD
        )

        guard case let .content(trustedContent) = trustedConfig else {
            return XCTFail("Expected trusted content")
        }
        guard case let .content(whitelistContent) = whitelistConfig else {
            return XCTFail("Expected whitelist content")
        }
        guard case let .content(unverifiedContent) = unverifiedConfig else {
            return XCTFail("Expected unverified content")
        }

        XCTAssertTrue(trustedContent.showsVerificationCheckmark)
        XCTAssertFalse(whitelistContent.showsVerificationCheckmark)
        XCTAssertFalse(unverifiedContent.showsVerificationCheckmark)
    }
}

private extension TradeAssetsListViewModelTests {
    @MainActor
    func makeViewModel(
        assetsListService: TradingAssetsListService,
        onOpenAssetDetails: @escaping (TradingAsset) -> Void = { _ in }
    ) -> TradeAssetsListViewModel {
        let formattersAssembly = FormattersAssembly()

        return TradeAssetsListViewModel(
            analyticsProvider: AnalyticsProvider(
                analyticsServices: [],
                uniqueIdProvider: CoreAssembly().uniqueIdProvider,
                appInfoProvider: CoreAssembly().appInfoProvider,
                keysCountryCodeProvider: CoreAssembly().keysCountryCodeProvider
            ),
            analyticsSource: .deepLink,
            assetsListService: assetsListService,
            amountFormatter: formattersAssembly.amountFormatter,
            signedAmountFormatter: formattersAssembly.signedAmountFormatter,
            selectedCategory: .all,
            onBack: {},
            onOpenAssetDetails: onOpenAssetDetails
        )
    }

    @MainActor
    func currentAssets(
        in queryViewModel: TradeAssetsListQueryViewModel
    ) -> [TradingAsset] {
        switch queryViewModel.state {
        case .idle:
            return []
        case let .loaded(rowData), let .failed(rowData, _), let .refreshing(rowData, _), let .loadingMore(rowData, _):
            return rowData.assets
        }
    }

    @MainActor
    func currentStateMessage(in queryViewModel: TradeAssetsListQueryViewModel) -> String? {
        switch queryViewModel.state {
        case let .failed(_, message):
            return message
        case .idle, .loaded, .refreshing, .loadingMore:
            return nil
        }
    }

    @MainActor
    func isRefreshing(_ queryViewModel: TradeAssetsListQueryViewModel) -> Bool {
        if case .refreshing = queryViewModel.state {
            return true
        }
        return false
    }

    func snapshot(
        ids: [String],
        category: TradingAssetCategory = .tokens,
        nextCursor: String?
    ) -> TradingAssetListSnapshot {
        TradingAssetListSnapshot(
            generatedAt: .now,
            currency: .USD,
            assets: ids.map { id in
                TradingAsset(
                    id: id,
                    symbol: id.uppercased(),
                    category: category,
                    name: id,
                    subtitle: id,
                    imageURL: nil,
                    price: nil,
                    priceFractionDigits: 0,
                    change24hPercent: nil,
                    change24hPercentFractionDigits: 0,
                    verification: .whitelist
                )
            },
            nextCursor: nextCursor
        )
    }

    func tradingAsset(
        id: String,
        verification: TradingVerification
    ) -> TradingAsset {
        TradingAsset(
            id: id,
            symbol: id.uppercased(),
            category: .tokens,
            name: id,
            subtitle: id,
            imageURL: nil,
            price: nil,
            priceFractionDigits: 0,
            change24hPercent: nil,
            change24hPercentFractionDigits: 0,
            verification: verification
        )
    }

    func waitUntil(
        timeout: TimeInterval = 2,
        intervalNanoseconds: UInt64 = 10_000_000,
        condition: @escaping () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if await condition() {
                return
            }

            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }

        XCTFail("Timed out waiting for condition")
    }
}

private actor TradingAssetsListServiceSpy: TradingAssetsListService {
    struct Request: Hashable {
        let query: String?
        let category: TradingAssetCategory
    }

    struct Plan {
        let result: Result<TradingAssetListSnapshot, TradingAssetsListServiceFailure>
        let delayNanoseconds: UInt64

        static func success(
            _ snapshot: TradingAssetListSnapshot,
            delayNanoseconds: UInt64 = 0
        ) -> Plan {
            Plan(
                result: .success(snapshot),
                delayNanoseconds: delayNanoseconds
            )
        }

        static func failure(
            _ error: TradingAssetsListServiceFailure,
            delayNanoseconds: UInt64 = 0
        ) -> Plan {
            Plan(
                result: .failure(error),
                delayNanoseconds: delayNanoseconds
            )
        }
    }

    private var cachedSnapshots = [Request: TradingAssetListSnapshot]()
    private var loadPlanQueue = [Plan]()
    private var loadNextPagePlanQueue = [Plan]()
    private var recordedLoadRequests = [Request]()
    private var recordedLoadNextPageRequests = [Request]()
    private var recordedCanceledLoadRequests = [Request]()

    func setLoadPlans(_ plans: [Plan]) {
        loadPlanQueue = plans
    }

    func setLoadNextPagePlans(_ plans: [Plan]) {
        loadNextPagePlanQueue = plans
    }

    func get(
        query: String?,
        category: TradingAssetCategory
    ) async -> TradingAssetListSnapshot? {
        cachedSnapshots[Request(query: query, category: category)]
    }

    func load(
        query: String?,
        category: TradingAssetCategory
    ) async throws(TradingAssetsListServiceFailure) -> TradingAssetListSnapshot {
        let request = Request(query: query, category: category)
        recordedLoadRequests.append(request)

        let plan = loadPlanQueue.removeFirst()
        let snapshot = try await execute(plan: plan, request: request)
        cachedSnapshots[request] = snapshot
        return snapshot
    }

    func loadNextPage(
        query: String?,
        category: TradingAssetCategory
    ) async throws(TradingAssetsListServiceFailure) -> TradingAssetListSnapshot? {
        let request = Request(query: query, category: category)
        recordedLoadNextPageRequests.append(request)

        guard !loadNextPagePlanQueue.isEmpty else {
            return nil
        }

        let plan = loadNextPagePlanQueue.removeFirst()
        let nextPage = try await execute(plan: plan, request: request)

        if let cachedSnapshot = cachedSnapshots[request] {
            let mergedSnapshot = cachedSnapshot.merged(with: nextPage)
            cachedSnapshots[request] = mergedSnapshot
            return mergedSnapshot
        } else {
            cachedSnapshots[request] = nextPage
            return nextPage
        }
    }

    func loadRequests() -> [Request] {
        recordedLoadRequests
    }

    func loadNextPageRequests() -> [Request] {
        recordedLoadNextPageRequests
    }

    func canceledLoadRequests() -> [Request] {
        recordedCanceledLoadRequests
    }

    private func execute(
        plan: Plan,
        request: Request
    ) async throws(TradingAssetsListServiceFailure) -> TradingAssetListSnapshot {
        if plan.delayNanoseconds > 0 {
            do {
                try await Task.sleep(nanoseconds: plan.delayNanoseconds)
            } catch {
                recordedCanceledLoadRequests.append(request)
                throw .networkError
            }
        }

        switch plan.result {
        case let .success(snapshot):
            return snapshot
        case let .failure(error):
            throw error
        }
    }
}

private actor CompletionProbe {
    private var completed = false

    func markCompleted() {
        completed = true
    }

    func isCompleted() -> Bool {
        completed
    }
}
