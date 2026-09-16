@testable import App
@testable import KeeperCore
@testable import TKCore
import TKUIKit
import XCTest

final class TokenChartViewModelTests: XCTestCase {
    @MainActor
    func test_initialLoad_withoutCache_presentsPlaceholderShimmer() async {
        let fake = ChartServiceFake()
        let recorder = ChartOutputRecorder()
        let viewModel = makeViewModel(chartService: fake, recorder: recorder)

        viewModel.viewDidLoad()

        await waitUntil { recorder.models.count == 1 }
        let model = recorder.models[0]
        XCTAssertEqual(model.chartData.style, .skeleton)
        guard let buttonsConfig = model.buttons, case .shimmer = buttonsConfig else {
            return XCTFail("initial loading must show shimmer buttons")
        }
        XCTAssertEqual(recorder.headers.count, 1)

        await waitUntil { fake.hasPendingLoad(for: .day) }
        fake.resolveLoad(for: .day, with: makeCoordinates(count: 5))

        await waitUntil { recorder.models.last?.chartData.style == .active }
        XCTAssertEqual(recorder.models.last?.chartData.coordinates.count, 5)
    }

    @MainActor
    func test_periodSwitch_withoutCache_presentsSkeletonWithNewSelectionImmediately() async {
        let fake = ChartServiceFake()
        let recorder = ChartOutputRecorder()
        let viewModel = makeViewModel(chartService: fake, recorder: recorder)
        await presentInitialData(viewModel: viewModel, fake: fake, recorder: recorder, count: 5)
        let headersCount = recorder.headers.count

        recorder.tapButton(period: .month)

        await waitUntil { recorder.models.last?.chartData.style == .skeleton }
        guard let model = recorder.models.last else {
            return XCTFail("no loading model presented")
        }
        XCTAssertEqual(model.chartData.coordinates.count, 5)
        guard let buttonsConfig = model.buttons, case let .buttons(buttons) = buttonsConfig else {
            return XCTFail("loading state must keep tappable buttons")
        }
        XCTAssertEqual(selectedTitles(buttons), [Period.month.title])
        XCTAssertEqual(recorder.headers.count, headersCount)
    }

    @MainActor
    func test_periodSwitch_dataArrival_presentsActiveDataAndHeader() async {
        let fake = ChartServiceFake()
        let recorder = ChartOutputRecorder()
        let viewModel = makeViewModel(chartService: fake, recorder: recorder)
        await presentInitialData(viewModel: viewModel, fake: fake, recorder: recorder, count: 5)
        let headersCount = recorder.headers.count

        recorder.tapButton(period: .month)
        await waitUntil { fake.hasPendingLoad(for: .month) }
        fake.resolveLoad(for: .month, with: makeCoordinates(count: 9))

        await waitUntil { recorder.models.last?.chartData.style == .active }
        XCTAssertEqual(recorder.models.last?.chartData.coordinates.count, 9)
        XCTAssertEqual(recorder.headers.count, headersCount + 1)
    }

    @MainActor
    func test_stalePeriodResponse_isNotPresented() async {
        let fake = ChartServiceFake()
        let recorder = ChartOutputRecorder()
        let viewModel = makeViewModel(chartService: fake, recorder: recorder)
        await presentInitialData(viewModel: viewModel, fake: fake, recorder: recorder, count: 5)

        recorder.tapButton(period: .month)
        await waitUntil { fake.hasPendingLoad(for: .month) }
        recorder.tapButton(period: .year)
        await waitUntil { fake.hasPendingLoad(for: .year) }

        fake.resolveLoad(for: .month, with: makeCoordinates(count: 9))
        fake.resolveLoad(for: .year, with: makeCoordinates(count: 3))

        await waitUntil { recorder.models.last?.chartData.style == .active }
        XCTAssertEqual(recorder.models.last?.chartData.coordinates.count, 3)
        XCTAssertFalse(recorder.models.contains { $0.chartData.style == .active && $0.chartData.coordinates.count == 9 })
    }
}

private extension TokenChartViewModelTests {
    @MainActor
    func makeViewModel(
        chartService: ChartServiceFake,
        recorder: ChartOutputRecorder
    ) -> ChartViewModelImplementation {
        let keeperCoreFormatters = KeeperCore.FormattersAssembly()
        let currencyStore = CurrencyStore(
            keeperInfoStore: KeeperInfoStore(
                keeperInfoRepository: KeeperInfoRepositoryMock(keeperInfo: nil)
            )
        )
        let viewModel = ChartViewModelImplementation(
            chartController: ChartV2Controller(
                asset: .multichain(assetId: "ton/mainnet/coin"),
                network: .mainnet,
                chartService: chartService,
                currencyStore: currencyStore
            ),
            currencyStore: currencyStore,
            chartFormatter: TKCore.FormattersAssembly().chartFormatter(
                dateFormatter: keeperCoreFormatters.dateFormatter,
                amountFormatter: keeperCoreFormatters.amountFormatter,
                signedAmountFormatter: keeperCoreFormatters.signedAmountFormatter
            )
        )
        viewModel.didUpdateChartData = { model in
            recorder.models.append(model)
        }
        viewModel.didUpdateHeader = { header in
            recorder.headers.append(header)
        }
        viewModel.didFailedUpdateChartData = { error in
            recorder.errors.append(error)
        }
        return viewModel
    }

    @MainActor
    func presentInitialData(
        viewModel: ChartViewModelImplementation,
        fake: ChartServiceFake,
        recorder: ChartOutputRecorder,
        count: Int
    ) async {
        viewModel.viewDidLoad()
        await waitUntil { fake.hasPendingLoad(for: .day) }
        fake.resolveLoad(for: .day, with: makeCoordinates(count: count))
        await waitUntil { recorder.models.last?.chartData.style == .active }
    }

    func makeCoordinates(count: Int) -> [KeeperCore.Coordinate] {
        (0 ..< count).map {
            KeeperCore.Coordinate(x: Double($0), y: Double($0 + 1))
        }
    }

    func selectedTitles(_ buttons: [ChartBottomButtonsView.Config.Button]) -> [String] {
        buttons.filter(\.isSelected).map(\.title)
    }

    func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("condition not met within \(timeout)s")
    }
}

private final class ChartOutputRecorder {
    var models = [TKUIKit.ChartView.Model]()
    var headers = [ChartHeaderView.Configuration]()
    var errors = [ChartErrorView.Model]()

    func tapButton(period: Period) {
        guard let config = models.last?.buttons, case let .buttons(buttons) = config else {
            return XCTFail("no tappable buttons in the last model")
        }
        guard let button = buttons.first(where: { $0.title == period.title }) else {
            return XCTFail("no button for period \(period)")
        }
        button.tapAction()
    }
}

private final class ChartServiceFake: ChartService, @unchecked Sendable {
    private let lock = NSLock()
    private var cachedData = [Period: [KeeperCore.Coordinate]]()
    private var pendingLoads = [(period: Period, continuation: CheckedContinuation<[KeeperCore.Coordinate], Swift.Error>)]()

    func setCachedData(_ coordinates: [KeeperCore.Coordinate], for period: Period) {
        lock.lock()
        defer { lock.unlock() }
        cachedData[period] = coordinates
    }

    func hasPendingLoad(for period: Period) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingLoads.contains { $0.period == period }
    }

    func resolveLoad(for period: Period, with coordinates: [KeeperCore.Coordinate]) {
        lock.lock()
        let resolved = pendingLoads.filter { $0.period == period }
        pendingLoads.removeAll { $0.period == period }
        lock.unlock()
        resolved.forEach { $0.continuation.resume(returning: coordinates) }
    }

    func getChartData(period: Period, asset: ChartAsset, currency: Currency, network: Network) -> [KeeperCore.Coordinate]? {
        lock.lock()
        defer { lock.unlock() }
        return cachedData[period]
    }

    func loadChartData(
        period: Period,
        asset: ChartAsset,
        currency: Currency,
        network: Network
    ) async throws(ChartServiceError) -> [KeeperCore.Coordinate] {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                defer { lock.unlock() }
                pendingLoads.append((period, continuation))
            }
        } catch {
            throw (error as? ChartServiceError) ?? .networkError
        }
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
