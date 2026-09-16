import Foundation
import KeeperCoreComponents
import TonSwift

protocol ChartDataRepository {
    func getChartData(period: Period, token: String, currency: Currency, network: Network) -> [Coordinate]?
    func saveChartData(coordinates: [Coordinate], period: Period, token: String, currency: Currency, network: Network) throws
}

final class SessionChartDataRepository: ChartDataRepository {
    private let lock = NSLock()
    private var storage = [String: [Coordinate]]()

    func getChartData(period: Period, token: String, currency: Currency, network: Network) -> [Coordinate]? {
        let key = cacheKey(
            period: period,
            token: token,
            currency: currency,
            network: network
        )
        lock.lock()
        defer { lock.unlock() }
        guard let coordinates = storage[key], !coordinates.isEmpty else {
            return nil
        }
        return coordinates
    }

    func saveChartData(coordinates: [Coordinate], period: Period, token: String, currency: Currency, network: Network) throws {
        let key = cacheKey(
            period: period,
            token: token,
            currency: currency,
            network: network
        )
        lock.lock()
        defer { lock.unlock() }
        storage[key] = coordinates
    }
}

struct PersistentChartDataRepository: ChartDataRepository {
    let fileSystemVault: FileSystemVault<[Coordinate], String>

    func getChartData(period: Period, token: String, currency: Currency, network: Network) -> [Coordinate]? {
        do {
            let coordinates = try fileSystemVault.loadItem(
                key: cacheKey(
                    period: period,
                    token: token,
                    currency: currency,
                    network: network
                )
            )
            return coordinates.isEmpty ? nil : coordinates
        } catch {
            return nil
        }
    }

    func saveChartData(coordinates: [Coordinate], period: Period, token: String, currency: Currency, network: Network) throws {
        try fileSystemVault.saveItem(
            coordinates,
            key: cacheKey(
                period: period,
                token: token,
                currency: currency,
                network: network
            )
        )
    }
}

private extension ChartDataRepository {
    func cacheKey(period: Period, token: String, currency: Currency, network: Network) -> String {
        let rawKey = "\(period.stringValue)_\(currency.code)_\(token)_\(network.rawValue)"
        return rawKey.addingPercentEncoding(withAllowedCharacters: .chartCacheKeyAllowedCharacters) ?? rawKey
    }
}

private extension CharacterSet {
    static let chartCacheKeyAllowedCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-:"
    )
}
