@testable import App
import AppUI
@testable import KeeperCore
import KeeperCoreComponents
import TKCore
import UIKit
import XCTest

@MainActor
final class WalletBalanceEarnPortfolioViewModelTests: XCTestCase {
    private var directory: URL!
    private var service: EarnPortfolioServiceStub!
    private var analytics: AnalyticsServiceSpy!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WalletBalanceEarnPortfolioViewModelTests-\(UUID().uuidString)")
        service = EarnPortfolioServiceStub()
        analytics = AnalyticsServiceSpy()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    func test_walletWithoutAnEvmAddressHasNoPortfolio() {
        let viewModel = makeViewModel(address: nil)

        XCTAssertEqual(viewModel.state, .noEVMAccount)
    }

    func test_evmAddressArrivingLaterLoadsItsPositions() async {
        service.result = .success(positions)
        let viewModel = makeViewModel(address: nil)
        viewModel.didAppear()

        viewModel.adopt(address: address)

        XCTAssertEqual(viewModel.state, .loading)
        await waitForState(of: viewModel) { $0 != .loading }
        XCTAssertEqual(viewModel.state, .positions(section(isStale: false)))
        XCTAssertEqual(service.requestedAddresses, [address])
    }

    func test_answerForAReplacedAddressIsDropped() async {
        service.holdsRequests = true
        let viewModel = makeViewModel(address: replacedAddress)
        let replacedLoad = Task { await viewModel.refresh() }
        await service.waitForRequests(1)

        viewModel.adopt(address: address)
        await service.waitForRequests(2)
        service.answer(address, with: .success([]))
        await waitForState(of: viewModel) { $0 == .empty }
        service.answer(replacedAddress, with: .success(positions))
        await replacedLoad.value

        XCTAssertEqual(viewModel.state, .empty)
        XCTAssertEqual(service.requestedAddresses, [replacedAddress, address])
    }

    func test_cachedPositionsShowBeforeTheFirstLoad() async throws {
        try await primeCache()
        service.result = .failure(URLError(.timedOut))

        let viewModel = makeViewModel(address: address)

        XCTAssertEqual(viewModel.state, .positions(section(isStale: false)))
    }

    func test_firstLoadStartsWhenTheScreenAppears() async {
        service.result = .success(positions)
        let viewModel = makeViewModel(address: address)

        viewModel.didAppear()

        await waitForState(of: viewModel) { $0 != .loading }
        XCTAssertEqual(viewModel.state, .positions(section(isStale: false)))
        XCTAssertEqual(service.requestedAddresses, [address])
    }

    func test_comingBackToTheScreenReloads() async {
        service.result = .success(positions)
        let viewModel = makeViewModel(address: address)
        viewModel.didAppear()
        await waitForState(of: viewModel) { $0 != .loading }
        service.result = .success([])

        viewModel.didDisappear()
        viewModel.didAppear()

        await waitForState(of: viewModel) { $0 == .empty }
        XCTAssertEqual(service.requestedAddresses, [address, address])
    }

    func test_returningFromTheBackgroundReloadsTheScreenOnDisplay() async {
        service.result = .success(positions)
        let viewModel = makeViewModel(address: address)
        viewModel.didAppear()
        await waitForState(of: viewModel) { $0 != .loading }
        service.result = .success([])

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        await waitForState(of: viewModel) { $0 == .empty }
        XCTAssertEqual(service.requestedAddresses, [address, address])
    }

    func test_loadedPositionsAreShown() async {
        service.result = .success(positions)
        let viewModel = makeViewModel(address: address)

        await viewModel.refresh()

        XCTAssertEqual(viewModel.state, .positions(section(isStale: false)))
    }

    func test_emptyAnswerIsEmptyOnlyAfterItArrives() async {
        service.result = .success([])
        let viewModel = makeViewModel(address: address)

        await viewModel.refresh()

        XCTAssertEqual(viewModel.state, .empty)
    }

    func test_failureWithACacheMarksItStale() async throws {
        try await primeCache()
        service.result = .failure(URLError(.timedOut))
        let viewModel = makeViewModel(address: address)

        await viewModel.refresh()

        XCTAssertEqual(viewModel.state, .positions(section(isStale: true)))
    }

    func test_failureWithoutACacheIsUnavailable() async {
        service.result = .failure(URLError(.timedOut))
        let viewModel = makeViewModel(address: address)

        await viewModel.refresh()

        XCTAssertEqual(viewModel.state, .unavailable)
    }

    func test_shownPositionsAreReportedOncePerAppearance() async {
        service.result = .success(positions)
        let viewModel = makeViewModel(address: address)
        await viewModel.refresh()

        viewModel.positionsDidAppear()
        viewModel.positionsDidAppear()
        viewModel.positionsDidDisappear()
        viewModel.positionsDidAppear()

        XCTAssertEqual(analytics.events.map(\.name), ["earn_entry_view", "earn_entry_view"])
        let args = analytics.events.first?.args
        XCTAssertEqual(args?["from"] as? String, "earn_your_vaults")
        XCTAssertEqual(args?["vaults_count"] as? Int, 1)
        XCTAssertEqual(args?["balance_usd"] as? Double, 1.92)
    }

    func test_emptyPortfolioIsNotReportedAsTheBlockOfVaults() async {
        service.result = .success([])
        let viewModel = makeViewModel(address: address)
        await viewModel.refresh()

        viewModel.positionsDidAppear()

        XCTAssertTrue(analytics.events.isEmpty)
    }

    func test_selectingARowReportsItsPosition() async {
        service.result = .success(positions)
        let viewModel = makeViewModel(address: address)
        var selected: EarnPosition?
        viewModel.onSelectPosition = { selected = $0 }
        await viewModel.refresh()

        viewModel.selectRow(id: "mainnet/0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c")

        XCTAssertEqual(selected, positions.first)
    }
}

private extension WalletBalanceEarnPortfolioViewModelTests {
    var address: String {
        "0x1111111111111111111111111111111111111111"
    }

    var replacedAddress: String {
        "0x2222222222222222222222222222222222222222"
    }

    var positions: [EarnPosition] {
        [
            EarnPosition(
                network: "mainnet",
                vaultId: "0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c",
                protocolName: "Aave",
                assetSymbol: "USDC",
                assetIconURL: nil,
                balanceUsd: Decimal(string: "1.92")!,
                earnedUsd: Decimal(string: "0.02")!
            ),
        ]
    }

    var repository: EarnPortfolioRepository {
        EarnPortfolioRepository(
            service: service,
            fileSystemVault: FileSystemVault(fileManager: .default, directory: directory)
        )
    }

    func section(isStale: Bool) -> EarnPortfolioSectionState {
        EarnPortfolioSectionState(totalBalance: "1.92", isStale: isStale, rows: [])
    }

    func waitForState(
        of viewModel: WalletBalanceEarnPortfolioViewModel,
        where isExpected: (WalletBalanceEarnPortfolioViewModel.State) -> Bool
    ) async {
        for await state in viewModel.$state.values where isExpected(state) {
            return
        }
    }

    var coreAssembly: TKCore.CoreAssembly {
        TKCore.CoreAssembly()
    }

    func primeCache() async throws {
        service.result = .success(positions)
        _ = try await repository.loadPositions(address: address)
    }

    func makeViewModel(address: String?) -> WalletBalanceEarnPortfolioViewModel {
        WalletBalanceEarnPortfolioViewModel(
            address: address,
            repository: repository,
            mapper: { positions, isStale in
                EarnPortfolioSectionState(
                    totalBalance: "\(positions.reduce(0) { $0 + $1.balanceUsd })",
                    isStale: isStale,
                    rows: []
                )
            },
            analyticsProvider: AnalyticsProvider(
                analyticsServices: [analytics],
                uniqueIdProvider: coreAssembly.uniqueIdProvider,
                appInfoProvider: coreAssembly.appInfoProvider,
                keysCountryCodeProvider: coreAssembly.keysCountryCodeProvider
            )
        )
    }
}

private final class AnalyticsServiceSpy: AnalyticsService {
    private(set) var events = [(name: String, args: [String: Any])]()

    func logEvent(name: String, args: [String: Any]) {
        events.append((name: name, args: args))
    }
}

@MainActor
private final class EarnPortfolioServiceStub: EarnPortfolioService {
    var result: Result<[EarnPosition], Error> = .failure(URLError(.unknown))
    var holdsRequests = false
    private(set) var requestedAddresses = [String]()
    private var heldRequests = [String: CheckedContinuation<Result<[EarnPosition], Error>, Never>]()
    private var requestWaiters = [CheckedContinuation<Void, Never>]()

    func loadPositions(address: String) async throws -> [EarnPosition] {
        requestedAddresses.append(address)
        let waiters = requestWaiters
        requestWaiters = []
        waiters.forEach { $0.resume() }
        guard holdsRequests else { return try result.get() }
        return try await withCheckedContinuation { heldRequests[address] = $0 }.get()
    }

    func waitForRequests(_ count: Int) async {
        while requestedAddresses.count < count {
            await withCheckedContinuation { requestWaiters.append($0) }
        }
    }

    func answer(_ address: String, with result: Result<[EarnPosition], Error>) {
        heldRequests.removeValue(forKey: address)?.resume(returning: result)
    }
}
