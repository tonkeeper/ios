import CoreComponents
import Foundation

struct CurrenciesCacheEntry: Codable {
    let value: [RemoteCurrency]
    let cachedAt: Date
}

protocol CurrenciesRepository {
    func getCurrencies() throws -> (data: [RemoteCurrency], cachedAt: Date)?
    func saveCurrencies(_ data: [RemoteCurrency]) throws
    func clearCache()
}

final class CurrenciesRepositoryImplementation: CurrenciesRepository {
    private let fileSystemVault: FileSystemVault<CurrenciesCacheEntry, String>

    init(fileSystemVault: FileSystemVault<CurrenciesCacheEntry, String>) {
        self.fileSystemVault = fileSystemVault
    }

    func getCurrencies() throws -> (data: [RemoteCurrency], cachedAt: Date)? {
        let entry = try? fileSystemVault.loadItem(key: Self.currenciesKey)
        return entry.map { ($0.value, $0.cachedAt) }
    }

    func saveCurrencies(_ data: [RemoteCurrency]) throws {
        try fileSystemVault.saveItem(CurrenciesCacheEntry(value: data, cachedAt: Date()), key: Self.currenciesKey)
    }

    func clearCache() {
        fileSystemVault.deleteAllItems()
    }
}

private extension CurrenciesRepositoryImplementation {
    static let currenciesKey = "Currencies"
}
