import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit

typealias ChartHeaderView = ModernChartHeaderView

protocol ChartModuleOutput: AnyObject {}

protocol ChartViewModel: AnyObject {
    var didUpdateHeader: ((ChartHeaderView.Configuration) -> Void)? { get set }
    var didUpdateChartData: ((TKUIKit.ChartView.Model) -> Void)? { get set }
    var didFailedUpdateChartData: ((ChartErrorView.Model) -> Void)? { get set }

    func viewDidLoad()
    func didSelectChartPoint(at index: Int)
    func didDeselectChartPoint()
}

final class ChartViewModelImplementation: ChartViewModel, ChartModuleOutput {
    // MARK: - ChartModuleOutput

    // MARK: - ChartViewModel

    var didUpdateHeader: ((ChartHeaderView.Configuration) -> Void)?
    var didUpdateChartData: ((TKUIKit.ChartView.Model) -> Void)?
    var didFailedUpdateChartData: ((ChartErrorView.Model) -> Void)?

    func viewDidLoad() {
        Task {
            await updateChart(diffAnimationStyle: .none)
        }
    }

    func didSelectChartPoint(at index: Int) {
        Task {
            let currency = currencyStore.state
            let period = await state.period
            let coordinates = await state.coordinates
            let pointModel = preparePointModel(
                index: index,
                coordinates: coordinates,
                currency: currency,
                period: period,
                diffAnimationStyle: .none
            )
            await MainActor.run {
                didUpdateHeader?(pointModel)
            }
        }
    }

    func didDeselectChartPoint() {
        Task {
            let currency = currencyStore.state
            let period = await state.period
            let coordinates = await state.coordinates
            let pointModel = prepareLastPointModel(
                coordinates: coordinates,
                currency: currency,
                period: period,
                diffAnimationStyle: .none
            )
            await MainActor.run {
                didUpdateHeader?(pointModel)
            }
        }
    }

    actor State {
        var period: Period = .day
        var coordinates = [KeeperCore.Coordinate]()
        var coordinatesPeriod: Period?

        func setPeriod(_ period: Period) {
            self.period = period
        }

        func setCoordinates(_ coordinates: [KeeperCore.Coordinate], period: Period) {
            self.coordinates = coordinates
            coordinatesPeriod = period
        }
    }

    // MARK: - State

    private var state = State()
    private var pollingTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let chartController: ChartV2Controller
    private let currencyStore: CurrencyStore
    private let chartFormatter: ChartFormatter

    // MARK: - Init

    init(
        chartController: ChartV2Controller,
        currencyStore: CurrencyStore,
        chartFormatter: ChartFormatter
    ) {
        self.chartController = chartController
        self.currencyStore = currencyStore
        self.chartFormatter = chartFormatter
    }
}

private extension ChartViewModelImplementation {
    func didSelectPeriodButtonAt(index: Int) {
        pollingTask?.cancel()
        Task {
            await state.setPeriod(Period.allCases[index])
            await updateChart(diffAnimationStyle: .rollingNumbers)
        }
    }

    func updateChart(
        diffAnimationStyle: ChartHeaderView.DiffAnimationStyle
    ) async {
        await displayLoadingChart()
        await loadChartData(diffAnimationStyle: diffAnimationStyle)
    }

    func displayLoadingChart() async {
        let selectedPeriod = await state.period
        let coordinates = await state.coordinates
        let coordinatesPeriod = await state.coordinatesPeriod

        if let coordinatesPeriod, !coordinates.isEmpty {
            let model = prepareLoadingChartModel(
                coordinates: coordinates,
                coordinatesPeriod: coordinatesPeriod,
                selectedPeriod: selectedPeriod,
                currency: currencyStore.state
            )
            await MainActor.run {
                didUpdateChartData?(model)
            }
        } else {
            let model = prepareSkeletonChartModel(period: selectedPeriod)
            await MainActor.run {
                didUpdateChartData?(model)
                didUpdateHeader?(shimmerHeaderModel())
            }
        }
    }

    func loadChartData(
        diffAnimationStyle: ChartHeaderView.DiffAnimationStyle
    ) async {
        pollingTask?.cancel()
        pollingTask = Task {
            let currency = currencyStore.state
            let period = await state.period

            let minimumVisibility = Task {
                try? await Task.sleep(nanoseconds: Self.loadingTransitionMinimumDuration)
            }

            var didPresentCachedData = false
            if let cachedCoordinates = chartController.getCachedChartData(period: period, currency: currency) {
                await minimumVisibility.value
                didPresentCachedData = await presentChartData(
                    coordinates: cachedCoordinates,
                    period: period,
                    currency: currency,
                    diffAnimationStyle: diffAnimationStyle
                )
            }

            do {
                let loadedCoordinates = try await chartController.loadChartData(
                    period: period,
                    currency: currency
                )
                await minimumVisibility.value
                await presentChartData(
                    coordinates: loadedCoordinates,
                    period: period,
                    currency: currency,
                    diffAnimationStyle: diffAnimationStyle
                )
            } catch {
                guard !error.isCancelledError else { return }
                guard !didPresentCachedData, await state.period == period else { return }
                let model = ChartErrorView.Model(
                    title: TKLocales.Chart.Error.title,
                    buttons: buttonsConfig(selectedPeriod: period)
                )
                await MainActor.run {
                    didFailedUpdateChartData?(model)
                    didUpdateHeader?(emptyHeaderModel())
                }
            }
        }
    }

    @discardableResult
    func presentChartData(
        coordinates: [KeeperCore.Coordinate],
        period: Period,
        currency: Currency,
        diffAnimationStyle: ChartHeaderView.DiffAnimationStyle
    ) async -> Bool {
        guard await state.period == period else { return false }
        await state.setCoordinates(coordinates, period: period)

        let model = prepareChartModel(
            coordinates: coordinates,
            period: period,
            currency: currency,
            style: .active
        )
        let lastPointModel = prepareLastPointModel(
            coordinates: coordinates,
            currency: currency,
            period: period,
            diffAnimationStyle: diffAnimationStyle
        )

        await MainActor.run {
            didUpdateChartData?(model)
            didUpdateHeader?(lastPointModel)
        }
        return true
    }

    func prepareChartModel(
        coordinates: [KeeperCore.Coordinate],
        period: Period,
        currency: Currency,
        style: TKLineChartCanvasView.VisualStyle
    ) -> TKUIKit.ChartView.Model {
        let mode = chartMode(for: period)
        let chartData = TKLineChartCanvasView.ChartData(
            mode: mode,
            coordinates: coordinates,
            smoothing: mode == .stepped ? .none : .tension(0.58),
            style: style,
            appearance: chartController.isMultichainAsset ? .trend : .standard
        )

        let values = coordinates.map { $0.y }
        let maximumValue = chartFormatter.mapMaxMinValue(value: values.max() ?? 0, currency: currency)
        let minimumValue = chartFormatter.mapMaxMinValue(value: values.min() ?? 0, currency: currency)

        var xAxisLeftValue = ""
        var xAxisMiddleValue = ""

        let leftValueIndex = coordinates.count / 10
        if coordinates.count > leftValueIndex {
            xAxisLeftValue = chartFormatter.formatXAxis(timeInterval: coordinates[leftValueIndex].x, period: period) ?? ""
        }
        let middleValueIndex = coordinates.count / 2
        if coordinates.count > middleValueIndex {
            xAxisMiddleValue = chartFormatter.formatXAxis(timeInterval: coordinates[middleValueIndex].x, period: period) ?? ""
        }

        return TKUIKit.ChartView.Model(
            chartData: chartData,
            topPrice: maximumValue,
            bottom: .init(
                bottomPrice: minimumValue,
                substrate: .init(
                    leftValue: xAxisLeftValue,
                    middleValue: xAxisMiddleValue,
                    style: style
                )
            ),
            buttons: buttonsConfig(selectedPeriod: period)
        )
    }

    func prepareLoadingChartModel(
        coordinates: [KeeperCore.Coordinate],
        coordinatesPeriod: Period,
        selectedPeriod: Period,
        currency: Currency
    ) -> TKUIKit.ChartView.Model {
        var model = prepareChartModel(
            coordinates: coordinates,
            period: coordinatesPeriod,
            currency: currency,
            style: .skeleton
        )
        model.buttons = buttonsConfig(selectedPeriod: selectedPeriod)
        return model
    }

    func prepareSkeletonChartModel(period: Period) -> TKUIKit.ChartView.Model {
        let mode = chartMode(for: period)
        let chartData = TKLineChartCanvasView.ChartData(
            mode: mode,
            coordinates: Self.skeletonCoordinates,
            smoothing: mode == .stepped ? .none : .tension(0.58),
            style: .skeleton
        )

        return TKUIKit.ChartView.Model(
            chartData: chartData,
            topPrice: "",
            bottom: .init(
                bottomPrice: "",
                substrate: .init(
                    leftValue: "",
                    middleValue: "",
                    style: .skeleton
                )
            ),
            buttons: .shimmer(count: Period.allCases.count)
        )
    }

    func buttonsConfig(selectedPeriod: Period) -> ChartBottomButtonsView.Config {
        let buttons = Period.allCases.enumerated().map { index, period in
            ChartBottomButtonsView.Config.Button(
                title: period.title,
                isSelected: period == selectedPeriod
            ) { [weak self] in
                self?.didSelectPeriodButtonAt(index: index)
            }
        }

        return .buttons(buttons)
    }

    func chartMode(for period: Period) -> TKLineChartCanvasView.ChartMode {
        switch period {
        case .hour:
            return .stepped
        default:
            return .linear
        }
    }

    func preparePointModel(
        coordinate: KeeperCore.Coordinate,
        coordinates: [KeeperCore.Coordinate],
        currency: Currency,
        date: String,
        diffAnimationStyle: ChartHeaderView.DiffAnimationStyle
    ) -> ChartHeaderView.Configuration {
        let calculatedDiff = chartController.calculateDiff(coordinates: coordinates, coordinate: coordinate)

        let price = chartFormatter.formatValue(coordinate: coordinate, currency: currency)
        let formattedDiff = chartFormatter.formatDiff(diff: calculatedDiff.diff)
        let formattedCurrencyDiff = chartFormatter.formatCurrencyDiff(diff: calculatedDiff.currencyDiff, currency: currency)

        let direction: ChartHeaderView.Diff.Direction
        switch calculatedDiff.diff {
        case let x where x < 0:
            direction = .down
        case let x where x > 0:
            direction = .up
        default:
            direction = .none
        }

        let diff = ChartHeaderView.Diff(
            diff: formattedDiff,
            priceDiff: formattedCurrencyDiff,
            direction: direction
        )
        return .content(
            .init(
                price: price,
                diff: diff,
                date: date,
                diffAnimationStyle: diffAnimationStyle
            )
        )
    }

    func prepareLastPointModel(
        coordinates: [KeeperCore.Coordinate],
        currency: Currency,
        period: Period,
        diffAnimationStyle: ChartHeaderView.DiffAnimationStyle
    ) -> ChartHeaderView.Configuration {
        guard let coordinate = coordinates.last else {
            return emptyHeaderModel()
        }
        return preparePointModel(
            coordinate: coordinate,
            coordinates: coordinates,
            currency: currency,
            date: period.chartDateTitle,
            diffAnimationStyle: diffAnimationStyle
        )
    }

    func preparePointModel(
        index: Int,
        coordinates: [KeeperCore.Coordinate],
        currency: Currency,
        period: Period,
        diffAnimationStyle: ChartHeaderView.DiffAnimationStyle
    ) -> ChartHeaderView.Configuration {
        guard index < coordinates.count else {
            return emptyHeaderModel()
        }
        let coordinate = coordinates[index]
        let date = chartFormatter.formatInformationTimeInterval(coordinate.x, period: period)
        return preparePointModel(
            coordinate: coordinate,
            coordinates: coordinates,
            currency: currency,
            date: date ?? "",
            diffAnimationStyle: diffAnimationStyle
        )
    }

    func shimmerHeaderModel() -> ChartHeaderView.Configuration {
        .shimmer
    }

    func emptyHeaderModel() -> ChartHeaderView.Configuration {
        .content(
            .init(
                price: "",
                diff: ChartHeaderView.Diff(
                    diff: "",
                    priceDiff: "",
                    direction: .none
                ),
                date: ""
            )
        )
    }
}

extension KeeperCore.Coordinate: TKUIKit.Coordinate {}

private extension ChartViewModelImplementation {
    static let loadingTransitionMinimumDuration: UInt64 = 300_000_000

    struct SkeletonCoordinate: TKUIKit.Coordinate {
        let x: Double
        let y: Double
    }

    static let skeletonCoordinates: [SkeletonCoordinate] = [
        .init(x: 0.0, y: 40.5),
        .init(x: 4.0, y: 40.5),
        .init(x: 16.0, y: 16.5),
        .init(x: 28.0, y: 20.5),
        .init(x: 40.0, y: 8.5),
        .init(x: 52.0, y: 14.5),
        .init(x: 64.0, y: 13.5),
        .init(x: 76.0, y: 23.5),
        .init(x: 88.0, y: 5.5),
        .init(x: 100.0, y: 55.5),
        .init(x: 112.0, y: 57.5),
        .init(x: 124.0, y: 71.5),
        .init(x: 136.0, y: 0.0),
        .init(x: 148.0, y: 18.5),
        .init(x: 160.0, y: 25.5),
        .init(x: 172.0, y: 5.5),
        .init(x: 184.0, y: 17.5),
        .init(x: 196.0, y: 15.5),
        .init(x: 207.0, y: 38.5),
        .init(x: 218.0, y: 36.5),
        .init(x: 232.0, y: 56.5),
        .init(x: 244.0, y: 63.5),
        .init(x: 255.5, y: 84.5),
        .init(x: 268.0, y: 71.5),
        .init(x: 280.0, y: 75.5),
        .init(x: 292.0, y: 95.5),
        .init(x: 304.0, y: 141.5),
        .init(x: 316.0, y: 145.5),
        .init(x: 328.0, y: 130.5),
        .init(x: 340.0, y: 164.5),
        .init(x: 350.0, y: 150.5),
        .init(x: 362.0, y: 153.5),
        .init(x: 372.0, y: 124.5),
        .init(x: 380.0, y: 144.5),
        .init(x: 390.0, y: 144.5),
    ]
}

private extension Period {
    var chartDateTitle: String {
        switch self {
        case .hour:
            return TKLocales.Chart.lastHour
        case .day:
            return TKLocales.Chart.lastDay
        case .week:
            return TKLocales.Chart.lastWeek
        case .month:
            return TKLocales.Chart.lastMonth
        case .halfYear:
            return TKLocales.Chart.lastHalfYear
        case .year:
            return TKLocales.Chart.lastYear
        }
    }
}
