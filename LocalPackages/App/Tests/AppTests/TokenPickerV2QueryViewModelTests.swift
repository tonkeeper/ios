@testable import App
import BigInt
@testable import KeeperCore
import TKCore
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
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(
            viewModel.presentation.items.compactMap(\.asset).map(\.asset.assetId),
            ["ton/mainnet/jetton/0:first", "ton/mainnet/jetton/0:second"]
        )
        XCTAssertEqual(model.cursors, [nil, "1"])
    }
}

private extension TokenPickerV2QueryViewModelTests {
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
