import Foundation
import KeeperCoreComponents
import TonSwift

protocol RatesRepository {
    func saveRates(_ rates: Rates) throws
    func getRates() throws -> Rates
}

struct RatesRepositoryImplementation: RatesRepository {
    private enum Key {
        static let usdt = "usdt"
        static let jettons = "jettons"
    }

    let fileSystemVault: FileSystemVault<[Rates.Rate], String>
    let jettonRatesVault: FileSystemVault<[String: [Rates.Rate]], String>

    func saveRates(_ rates: Rates) throws {
        try fileSystemVault.saveItem(rates.ton, key: TonInfo.symbol.lowercased())
        try fileSystemVault.saveItem(rates.usdt, key: Key.usdt)
        try jettonRatesVault.saveItem(rates.jettonRates, key: Key.jettons)
    }

    func getRates() throws -> Rates {
        let tonRates = try fileSystemVault.loadItem(key: TonInfo.symbol.lowercased())
        let usdtRates = try fileSystemVault.loadItem(key: Key.usdt)
        // Written only since these were persisted at all, so an install that predates it restores
        // the two rates it does have rather than none.
        let jettonRates = try? jettonRatesVault.loadItem(key: Key.jettons)

        return Rates(
            ton: tonRates,
            usdt: usdtRates,
            jettonRates: jettonRates ?? [:]
        )
    }
}
