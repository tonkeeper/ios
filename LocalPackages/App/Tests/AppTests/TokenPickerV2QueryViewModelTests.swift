@testable import App
import BigInt
@testable import KeeperCore
import TKCore
import TKTestSupport
import XCTest

final class TokenPickerV2QueryViewModelTests: XCTestCase {
    @MainActor
    func test_refresh_setsVerificationCheckmarkOnlyForTrustedAssets() async {
        let viewModel = makeViewModel(
            displayMode: .includingMarketData,
            assets: [
                makeAsset(id: "eth/mainnet/coin", verification: .trusted),
                makeAsset(id: "eth/mainnet/erc20/0xwl", verification: .whitelist),
                makeAsset(id: "eth/mainnet/erc20/0x123", verification: .none),
            ]
        )

        await viewModel.refresh()

        XCTAssertEqual(
            viewModel.presentation.items.compactMap(\.assetRow).map(\.showsVerificationCheckmark),
            [true, false, false]
        )
    }

    @MainActor
    func test_refresh_setsVerificationCheckmarkForSelectionRows() async {
        let viewModel = makeViewModel(
            displayMode: .includingSelection(nil),
            assets: [makeAsset(id: "ton/mainnet/jetton/0:123", verification: .trusted)]
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.presentation.items.compactMap(\.assetRow).map(\.showsVerificationCheckmark), [true])
    }

    @MainActor
    func test_loadNextPageIfNeeded_paginatesFromListTailWhileSectionsAreSplit() async {
        let model = TokenPickerV2ModelFake(
            pages: [
                [makeAsset(id: "ton/mainnet/jetton/0:first", verification: .trusted)],
                [makeAsset(id: "ton/mainnet/jetton/0:second", verification: .trusted)],
            ]
        )
        let viewModel = TokenPickerV2QueryViewModel(
            query: "ton",
            category: .all,
            displayMode: .includingMarketData,
            tokenPickerModel: model,
            amountFormatter: FormattersAssembly().amountFormatter,
            currencyStore: makeCurrencyStore()
        )

        await viewModel.refresh()
        XCTAssertTrue(viewModel.splitsPerpetualsIntoSections)
        guard let lastItem = viewModel.presentation.items.last else {
            return XCTFail("Expected the first page to load")
        }

        viewModel.loadNextPageIfNeeded(currentItem: lastItem)
        await waitUntil(viewModel) { viewModel.presentation.items.count == 2 }

        XCTAssertEqual(
            viewModel.presentation.items.compactMap(\.asset).map(\.asset.assetId),
            ["ton/mainnet/jetton/0:first", "ton/mainnet/jetton/0:second"]
        )
        XCTAssertEqual(model.cursors, [nil, "1"])
    }

    @MainActor
    func test_appeared_reloadsExpiredListBehindItsRows() async {
        let model = TokenPickerV2ModelFake(assets: [makeAsset(id: "ton/mainnet/coin", verification: .trusted)])
        let viewModel = TokenPickerV2QueryViewModel(
            query: nil,
            category: .all,
            displayMode: .includingMarketData,
            tokenPickerModel: model,
            amountFormatter: FormattersAssembly().amountFormatter,
            currencyStore: makeCurrencyStore(),
            cacheLifetime: 0
        )
        await viewModel.refresh()

        viewModel.appeared()

        XCTAssertFalse(viewModel.presentation.showsSkeleton)
        XCTAssertEqual(viewModel.presentation.items.count, 1)
        guard case let .refreshing(_, task) = viewModel.state else {
            return XCTFail("Expected an expired list to reload")
        }
        await task.value
        XCTAssertEqual(model.cursors, [nil, nil])
    }

    @MainActor
    func test_appeared_keepsExpiredListWithMoreThanItsFirstPage() async throws {
        let firstPage = (0 ..< 30).map { makeAsset(id: "ton/mainnet/jetton/0:\($0)", verification: .trusted) }
        let model = TokenPickerV2ModelFake(pages: [firstPage, [makeAsset(id: "ton/mainnet/jetton/0:last", verification: .trusted)]])
        let viewModel = makeViewModel(model: model, cacheLifetime: 0)
        await viewModel.refresh()
        try viewModel.loadNextPageIfNeeded(currentItem: XCTUnwrap(viewModel.presentation.items.last))
        if case let .loadingMore(_, task) = viewModel.state {
            await task.value
        }

        viewModel.appeared()

        XCTAssertEqual(viewModel.presentation.items.count, 31)
        XCTAssertEqual(model.cursors, [nil, "1"])
    }

    @MainActor
    func test_reopenedEmptyListStaysLoadedWithoutRequest() async {
        let model = TokenPickerV2ModelFake(assets: [])
        let viewModel = makeViewModel(model: model, cacheLifetime: 0)
        await viewModel.refresh()

        viewModel.disappeared()
        viewModel.appeared()

        XCTAssertFalse(viewModel.presentation.showsSkeleton)
        XCTAssertEqual(viewModel.presentation.placeholder, .empty)
        XCTAssertEqual(model.cursors, [nil])
    }

    @MainActor
    func test_appeared_reloadsExpiredFirstPageLongerThanPageSize() async {
        let firstPage = (0 ..< 50).map { makeAsset(id: "ton/mainnet/jetton/0:\($0)", verification: .trusted) }
        let model = TokenPickerV2ModelFake(pages: [firstPage])
        let viewModel = makeViewModel(model: model, cacheLifetime: 0)
        await viewModel.refresh()

        viewModel.appeared()

        guard case let .refreshing(rowData, task) = viewModel.state else {
            return XCTFail("Expected an expired first page to reload")
        }
        XCTAssertEqual(rowData.items.count, 50)
        await task.value
        XCTAssertEqual(model.cursors, [nil, nil])
    }

    @MainActor
    func test_failedFirstPageReloadsWhenReopenedAfterDisappearing() async {
        let model = TokenPickerV2ModelFake(assets: [makeAsset(id: "ton/mainnet/coin", verification: .trusted)])
        let viewModel = makeViewModel(model: model, cacheLifetime: 60)
        model.failsNextLoad = true
        await viewModel.refresh()
        guard case .failed = viewModel.state else {
            return XCTFail("Expected the first page to fail")
        }

        viewModel.disappeared()
        viewModel.appeared()
        guard case let .refreshing(_, task) = viewModel.state else {
            return XCTFail("Expected a failed list to reload once reopened")
        }
        await task.value

        XCTAssertEqual(viewModel.presentation.items.count, 1)
        XCTAssertEqual(model.cursors, [nil, nil])
    }
}

private extension TokenPickerV2QueryViewModelTests {
    @MainActor
    func makeViewModel(model: TokenPickerV2ModelFake, cacheLifetime: TimeInterval) -> TokenPickerV2QueryViewModel {
        TokenPickerV2QueryViewModel(
            query: nil,
            category: .all,
            displayMode: .includingMarketData,
            tokenPickerModel: model,
            amountFormatter: FormattersAssembly().amountFormatter,
            currencyStore: makeCurrencyStore(),
            cacheLifetime: cacheLifetime
        )
    }

    @MainActor
    func makeViewModel(
        displayMode: SendTokenV2PickerDisplayMode,
        assets: [MultichainAsset]
    ) -> TokenPickerV2QueryViewModel {
        TokenPickerV2QueryViewModel(
            query: nil,
            category: .all,
            displayMode: displayMode,
            tokenPickerModel: TokenPickerV2ModelFake(assets: assets),
            amountFormatter: FormattersAssembly().amountFormatter,
            currencyStore: makeCurrencyStore()
        )
    }

    func makeCurrencyStore() -> CurrencyStore {
        CurrencyStore(
            keeperInfoStore: KeeperInfoStore(
                keeperInfoRepository: KeeperInfoRepositoryMock(keeperInfo: nil)
            )
        )
    }

    func makeAsset(
        id: String,
        verification: MultichainAssetVerification
    ) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: id,
                name: "Ethereum",
                symbol: "ETH",
                decimals: 18,
                image: "",
                verification: verification
            ),
            price: MultichainAssetPrice(
                prices: [:],
                diff24h: [:],
                diff7d: [:]
            ),
            balance: BigUInt(1)
        )
    }
}

private final class TokenPickerV2ModelFake: TokenPickerV2Model {
    private let pages: [[MultichainAsset]]
    private(set) var cursors = [String?]()
    var failsNextLoad = false

    init(assets: [MultichainAsset]) {
        pages = [assets]
    }

    init(pages: [[MultichainAsset]]) {
        self.pages = pages
    }

    var showsCatalogSortControl: Bool {
        false
    }

    private(set) var catalogSearchSort: MultichainAssetSearchSort = .marketCap

    let initialState = TokenPickerV2ModelState(
        filters: [.all],
        displayMode: .includingMarketData,
        initialFilter: .all
    )

    func loadAssets(
        query _: String?,
        filter _: TokenPickerV2ChainFilter,
        limit _: Int,
        cursor: String?
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        cursors.append(cursor)
        if failsNextLoad {
            failsNextLoad = false
            throw .apiError(message: nil)
        }
        let index = cursor.flatMap(Int.init) ?? 0
        return TokenPickerLoadResult(
            assets: pages[index],
            nextCursor: index + 1 < pages.count ? String(index + 1) : nil
        )
    }

    func setCatalogSearchSort(_ sort: MultichainAssetSearchSort) {
        catalogSearchSort = sort
    }
}

private final class KeeperInfoRepositoryMock: KeeperInfoRepository {
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
        keeperInfo = nil
    }
}
