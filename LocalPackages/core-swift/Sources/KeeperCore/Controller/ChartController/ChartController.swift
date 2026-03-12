import Foundation

public final class ChartController: @unchecked Sendable {
    public var didUpdateChartData: (() -> Void)?

    private let chartService: ChartService
    private let tonRatesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let amountFormatter: AmountFormatter
    private let dateFormatter = DateFormatter()

    private var loadChartDataTask: Task<[Coordinate], Error>?
    public private(set) var coordinates = [Coordinate]()

    init(
        chartService: ChartService,
        tonRatesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        amountFormatter: AmountFormatter
    ) {
        self.chartService = chartService
        self.tonRatesStore = tonRatesStore
        self.currencyStore = currencyStore
        self.amountFormatter = amountFormatter
    }

    public func start() async {
        tonRatesStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateRates:
                DispatchQueue.main.async {
                    observer.didUpdateChartData?()
                }
            }
        }
    }

    public func loadChartData(period: Period) async throws -> [Coordinate] {
        loadChartDataTask?.cancel()
        let currency = currencyStore.state
        let task = Task {
            async let coordinatesTask = self.chartService.loadChartData(
                period: period,
                token: "ton",
                currency: currency, network: .mainnet
            )
            let rates = tonRatesStore.state.tonRates
            let coordinates = try await coordinatesTask

            try Task.checkCancellation()
            loadChartDataTask = nil
            return convertCoordinates(
                coordinates: coordinates,
                tonRates: rates,
                currency: currency
            )
        }
        self.loadChartDataTask = task
        self.coordinates = try await task.value
        return self.coordinates
    }

    public func getInformation(at index: Int, period: Period) async -> ChartPointInformationModel {
        guard index < coordinates.count else {
            return ChartPointInformationModel(
                amount: "",
                diff: .init(percent: "", fiat: "", direction: .none),
                date: ""
            )
        }
        let currency = currencyStore.state
        let coordinate = coordinates[index]

        let percentageValue = calculatePercentageDiff(at: index)
        let fiatValue = calculateFiatDiff(percentage: percentageValue)

        let amount = amountFormatter.format(
            decimal: Decimal(coordinate.y),
            accessory: .currency(currency),
            style: .compact
        )
        var percentage = String(format: "%.2f%%", percentageValue)
        let fiat = amountFormatter.format(
            decimal: Decimal(fiatValue),
            accessory: .currency(currency),
            style: .compact
        )
        let date = formatTimeInterval(coordinate.x, period: period) ?? ""

        let diffDirection: ChartPointInformationModel.Diff.Direction
        if percentageValue > 0 {
            diffDirection = .up
            percentage = "+" + percentage
        } else if percentageValue < 0 {
            diffDirection = .down
        } else {
            diffDirection = .none
        }

        return ChartPointInformationModel(
            amount: amount,
            diff: .init(percent: percentage, fiat: fiat, direction: diffDirection),
            date: date
        )
    }

    public func getMaximumValue(currency: Currency) -> String {
        guard let coordinate = coordinates.max(by: { $0.y < $1.y }) else {
            return ""
        }
        return String(format: "\(currency.symbol)%.2f", coordinate.y)
    }

    public func getMinimumValue(currency: Currency) -> String {
        guard let coordinate = coordinates.max(by: { $0.y > $1.y }) else {
            return ""
        }
        return String(format: "\(currency.symbol)%.2f", coordinate.y)
    }
}

private extension ChartController {
    func calculatePercentageDiff(at index: Int) -> Double {
        let startValue = coordinates[0].y
        guard startValue != 0 else { return 0 }
        let endValue = coordinates[index].y
        return (endValue / startValue - 1) * 100
    }

    func calculateFiatDiff(percentage: Double) -> Double {
        let startValue = coordinates[0].y
        let fiatDiff = (startValue / 100) * percentage
        return abs(fiatDiff)
    }

    func formatTimeInterval(
        _ timeInterval: TimeInterval,
        period: Period
    ) -> String? {
        let dateFormat: String
        switch period {
        case .hour: dateFormat = "E',' d MMM HH:mm"
        case .day: dateFormat = "E',' d MMM HH:mm"
        case .week: dateFormat = "E',' d MMM HH:mm"
        case .month: dateFormat = "E',' d MMM"
        case .halfYear: dateFormat = "yyyy E',' d MMM"
        case .year: dateFormat = "yyyy E',' d MMM"
        }

        dateFormatter.dateFormat = dateFormat
        dateFormatter.locale = Locale.current

        return dateFormatter.string(from: Date(timeIntervalSince1970: timeInterval))
    }

    // TODO: Remove once tonapi v2 chart request will fit requirements
    func convertCoordinates(
        coordinates: [Coordinate],
        tonRates: [Rates.Rate],
        currency: Currency
    ) -> [Coordinate] {
        guard let currencyRates = tonRates.first(where: { $0.currency == currency }),
              let usdRates = tonRates.first(where: { $0.currency == .USD })
        else {
            return coordinates
        }
        let coeff = NSDecimalNumber(decimal: usdRates.rate / currencyRates.rate).doubleValue
        return coordinates.map { coordinate in
            .init(x: coordinate.x, y: coordinate.y / coeff)
        }
    }
}
