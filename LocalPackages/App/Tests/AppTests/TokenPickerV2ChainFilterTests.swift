@testable import App
import BigInt
@testable import KeeperCore
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
}

private extension TokenPickerV2ChainFilterTests {
    @MainActor
    func makeViewModel(model: TokenPickerV2ModelSpy) -> TokenPickerV2ViewModelImplementation {
        TokenPickerV2ViewModelImplementation(
            headerTitle: "",
            tokenPickerModel: model,
            amountFormatter: FormattersAssembly().amountFormatter,
            currencyStore: CurrencyStore(
                keeperInfoStore: KeeperInfoStore(
                    keeperInfoRepository: KeeperInfoRepositoryStub()
                )
            )
        )
    }
}

private final class TokenPickerV2ModelSpy: TokenPickerV2Model {
    struct Request: Equatable {
        let query: String?
        let filter: TokenPickerV2ChainFilter
    }

    private(set) var requests = [Request]()

    var showsCatalogSortControl: Bool {
        false
    }

    private(set) var catalogSearchSort: MultichainAssetSearchSort = .marketCap

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
        requests.append(Request(query: query, filter: filter))
        return TokenPickerLoadResult(assets: [], nextCursor: nil)
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
