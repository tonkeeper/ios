import Foundation

public final class ChartV2Controller {
    private let token: Token
    private let chartService: ChartService
    private let currencyStore: CurrencyStore
    private let walletsService: WalletsService
    private let dateFormatter = DateFormatter()

    init(
        token: Token,
        chartService: ChartService,
        currencyStore: CurrencyStore,
        walletsService: WalletsService
    ) {
        self.token = token
        self.chartService = chartService
        self.currencyStore = currencyStore
        self.walletsService = walletsService
    }

    public func getCachedChartData(period: Period, currency: Currency) -> [Coordinate] {
        return chartService.getChartData(
            period: period,
            token: token.chartIdentifier,
            currency: currency,
            network: (try? walletsService.getActiveWallet().network) ?? .mainnet
        )
    }

    public func loadChartData(period: Period, currency: Currency) async throws -> [Coordinate] {
        return try await chartService.loadChartData(
            period: period,
            token: token.chartIdentifier,
            currency: currency,
            network: (try? walletsService.getActiveWallet().network) ?? .mainnet
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
