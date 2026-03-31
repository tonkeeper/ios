import Foundation

protocol CurrenciesAPI {
    func loadCurrencies() async throws -> [RemoteCurrency]
}

final class CurrenciesAPIImplementation: CurrenciesAPI {
    private let urlSession: URLSession
    private let urlComponentsBuilder: AppInfoURLComponentsBuilder
    private let bootHost: URL
    private let blockHost: URL

    init(
        urlSession: URLSession,
        bootHost: URL,
        blockHost: URL,
        appInfoProvider: AppInfoProvider
    ) {
        self.urlSession = urlSession
        self.bootHost = bootHost
        self.blockHost = blockHost
        self.urlComponentsBuilder = AppInfoURLComponentsBuilder(appInfoProvider: appInfoProvider)
    }

    func loadCurrencies() async throws -> [RemoteCurrency] {
        do {
            return try await loadCurrencies(host: bootHost)
        } catch {
            return try await loadCurrencies(host: blockHost)
        }
    }

    private func loadCurrencies(host: URL) async throws -> [RemoteCurrency] {
        let url = host.appendingPathComponent("currencies")
        let components = try await urlComponentsBuilder.buildURLComponents(for: url)
        guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
        let (data, _) = try await urlSession.data(from: url)
        return try JSONDecoder().decode(CurrenciesResult.self, from: data).currencies
    }
}

private struct CurrenciesResult: Codable {
    let currencies: [RemoteCurrency]
}
