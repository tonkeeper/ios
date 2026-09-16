@testable import App
@testable import KeeperCore
import XCTest

final class TokenManagementChainFilterTests: XCTestCase {
    @MainActor
    func test_selectCategory_keepsSearchTextAndScopesQueryToChain() async {
        let service = TokenManagementServiceSpy()
        let viewModel = makeViewModel(service: service)
        viewModel.viewDidLoad()
        viewModel.updateSearchText("app")

        viewModel.selectCategory("eth")

        XCTAssertEqual(viewModel.searchText, "app")

        await viewModel.currentQueryViewModel?.refresh()

        XCTAssertEqual(service.requests.last?.search, "app")
        XCTAssertEqual(service.requests.last?.chainID, "eth")
    }

    @MainActor
    func test_selectCategory_withoutSearchTextLoadsWholeChain() async {
        let service = TokenManagementServiceSpy()
        let viewModel = makeViewModel(service: service)
        viewModel.viewDidLoad()

        viewModel.selectCategory("eth")

        await viewModel.currentQueryViewModel?.refresh()

        XCTAssertNil(service.requests.last?.search)
        XCTAssertEqual(service.requests.last?.chainID, "eth")
    }

    @MainActor
    func test_setHidesDustBalances_reloadsCurrentQueryWithDustFilter() async {
        let service = TokenManagementServiceSpy()
        let viewModel = makeViewModel(service: service)
        let requestExpectation = expectation(description: "Dust-filtered request")
        service.onRequest = { request in
            guard request.hidesDustBalances else { return }
            requestExpectation.fulfill()
        }
        viewModel.viewDidLoad()

        viewModel.setHidesDustBalances(true)
        await fulfillment(of: [requestExpectation], timeout: 1)

        XCTAssertTrue(
            service.requests.contains {
                $0.hidesDustBalances
            }
        )
    }
}

private extension TokenManagementChainFilterTests {
    @MainActor
    func makeViewModel(service: TokenManagementServiceSpy) -> TokenManagementViewModelImplementation {
        TokenManagementViewModelImplementation(
            availableChains: [
                TokenManagementChain(id: "ton", title: "TON", badgeTitle: "TON", icon: nil),
                TokenManagementChain(id: "eth", title: "Ethereum", badgeTitle: "ETH", icon: nil),
            ],
            service: service,
            appSettingsStore: AppSettingsStore(
                keeperInfoStore: KeeperInfoStore(keeperInfoRepository: EmptyKeeperInfoRepositoryStub())
            )
        )
    }
}

private struct EmptyKeeperInfoRepositoryStub: KeeperInfoRepository {
    struct StubError: Error {}

    func getKeeperInfo() throws -> KeeperInfo {
        throw StubError()
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}

@MainActor
private final class TokenManagementServiceSpy: TokenManagementService {
    struct Request: Equatable {
        let chainID: String?
        let search: String?
        let hidesDustBalances: Bool
    }

    var didLoadBalances: (([TokenManagementBalanceItem]) -> Void)?
    var onRequest: ((Request) -> Void)?
    private(set) var requests = [Request]()

    func loadAssets(
        chainID: String?,
        search: String?,
        hidesDustBalances: Bool,
        limit _: Int,
        cursor _: String?
    ) async throws(MultichainServiceError) -> TokenManagementAssetsPage {
        let request = Request(
            chainID: chainID,
            search: search,
            hidesDustBalances: hidesDustBalances
        )
        requests.append(request)
        onRequest?(request)
        return TokenManagementAssetsPage(balances: [], nextCursor: nil)
    }

    func saveVisibilityChanges(_: [MultichainAssetFilterChange]) throws -> TokenManagementVisibilityUpdate {
        TokenManagementVisibilityUpdate(changes: [], visibleAssets: [])
    }
}
