import Foundation

protocol ChartService {
    func loadChartData(
        period: Period,
        token: String,
        currency: Currency,
        network: Network
    ) async throws -> [Coordinate]
    func getChartData(
        period: Period,
        token: String,
        currency: Currency,
        network: Network
    ) -> [Coordinate]
}

final class ChartServiceImplementation: ChartService {
    private let apiProvider: APIProvider
    private let repository: ChartDataRepository

    init(
        apiProvider: APIProvider,
        repository: ChartDataRepository
    ) {
        self.apiProvider = apiProvider
        self.repository = repository
    }

    func loadChartData(
        period: Period,
        token: String,
        currency: Currency,
        network: Network
    ) async throws -> [Coordinate] {
        let coordinates = try await apiProvider.api(network).getChart(
            token: token,
            period: period,
            currency: currency
        )
        try? repository.saveChartData(
            coordinates: coordinates,
            period: period,
            token: token,
            currency: currency,
            network: network
        )
        return coordinates
    }

    func getChartData(
        period: Period,
        token: String,
        currency: Currency,
        network: Network
    ) -> [Coordinate] {
        return repository.getChartData(
            period: period,
            token: token,
            currency: currency,
            network: network
        )
    }
}
