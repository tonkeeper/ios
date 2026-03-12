import Foundation
import TonAPI
import TonSwift

public protocol DNSService {
    func resolveDomainName(_ domainName: String, addTonPostfix: Bool, network: Network) async throws -> Domain
    func loadDomainExpirationDate(_ domainName: String, network: Network) async throws -> Date?
}

public extension DNSService {
    func resolveDomainName(_ domainName: String, network: Network) async throws -> Domain {
        try await resolveDomainName(domainName, addTonPostfix: false, network: network)
    }
}

final class DNSServiceImplementation: DNSService {
    enum Error: Swift.Error {
        case noWalletData
    }

    private let apiProvider: APIProvider

    init(apiProvider: APIProvider) {
        self.apiProvider = apiProvider
    }

    func resolveDomainName(_ domainName: String, addTonPostfix: Bool, network: Network) async throws -> Domain {
        let normalizedDomainName = domainName.lowercased()
        let resolveName: String = {
            if addTonPostfix {
                return parseDomainName(normalizedDomainName)
            } else {
                return normalizedDomainName
            }
        }()

        let result = try await apiProvider.api(network).resolveDomainName(resolveName)
        return Domain(domain: resolveName, friendlyAddress: result)
    }

    func loadDomainExpirationDate(_ domainName: String, network: Network) async throws -> Date? {
        return try await apiProvider.api(network).getDomainExpirationDate(domainName)
    }
}

private extension DNSServiceImplementation {
    func parseDomainName(_ domainName: String) -> String {
        guard let url = URL(string: domainName) else { return domainName }
        if url.pathExtension.isEmpty {
            return "\(domainName).ton"
        }
        return domainName
    }
}
