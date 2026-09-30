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
                diff7d: [:],
                diff30d: [:]
            ),
            balance: BigUInt(1)
        )
    }
}

private final class TokenPickerV2ModelFake: TokenPickerV2Model {
    private let assets: [MultichainAsset]

    init(assets: [MultichainAsset]) {
        self.assets = assets
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
        cursor _: String?
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        TokenPickerLoadResult(assets: assets, nextCursor: nil)
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
