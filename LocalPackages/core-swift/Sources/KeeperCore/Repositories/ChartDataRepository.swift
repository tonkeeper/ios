import CoreComponents
import Foundation
import TonSwift

protocol ChartDataRepository {
    func getChartData(period: Period, token: String, currency: Currency, network: Network) -> [Coordinate]
    func saveChartData(coordinates: [Coordinate], period: Period, token: String, currency: Currency, network: Network) throws
}

struct ChartDataRepositoryImplementation: ChartDataRepository {
    let fileSystemVault: FileSystemVault<[Coordinate], String>

    func getChartData(period: Period, token: String, currency: Currency, network: Network) -> [Coordinate] {
        do {
            return try fileSystemVault.loadItem(
                key: key(
                    period: period,
                    token: token,
                    currency: currency,
                    network: network
                )
            )
        } catch {
            return []
        }
    }

    func saveChartData(coordinates: [Coordinate], period: Period, token: String, currency: Currency, network: Network) throws {
        try fileSystemVault.saveItem(
            coordinates,
            key: key(
                period: period,
                token: token,
                currency: currency,
                network: network
            )
        )
    }

    private func key(period: Period, token: String, currency: Currency, network: Network) -> String {
        return "\(period.stringValue)_\(currency.code)_\(token)_\(network.rawValue)"
    }
}
