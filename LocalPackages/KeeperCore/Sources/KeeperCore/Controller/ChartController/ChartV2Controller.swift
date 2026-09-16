import Foundation

public final class ChartV2Controller {
    public var isMultichainAsset: Bool {
        asset.isMultichain
    }

    private let asset: ChartAsset
    private let network: Network
    private let chartService: ChartService
    private let currencyStore: CurrencyStore
    init(
        asset: ChartAsset,
        network: Network,
        chartService: ChartService,
        currencyStore: CurrencyStore
    ) {
        self.asset = asset
        self.network = network
        self.chartService = chartService
        self.currencyStore = currencyStore
    }

    public func getCachedChartData(period: Period, currency: Currency) -> [Coordinate]? {
        return chartService.getChartData(
            period: period,
            asset: asset,
            currency: currency,
            network: network
        )
    }

    public func loadChartData(period: Period, currency: Currency) async throws -> [Coordinate] {
        return try await chartService.loadChartData(
            period: period,
            asset: asset,
            currency: currency,
            network: network
        )
    }

    public func calculateDiff(
        coordinates: [Coordinate],
        coordinate: Coordinate
    ) -> (diff: Double, currencyDiff: Double) {
        guard let startCoordinate = coordinates.first else { return (0, 0) }
        let diff = (coordinate.y / startCoordinate.y - 1) * 100
        let currencyDiff = (coordinate.y - startCoordinate.y)
        return (diff, currencyDiff)
    }
}
