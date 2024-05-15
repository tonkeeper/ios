import Foundation
import TonAPI
import TonSwift

protocol DNSService {
  func resolveDomainName(_ domainName: String, isTestnet: Bool) async throws -> Domain
  func loadDomainExpirationDate(_ domainName: String, isTestnet: Bool) async throws -> Date?
}

final class DNSServiceImplementation: DNSService {
  enum Error: Swift.Error {
    case noWalletData
  }
  
  private let apiProvider: APIProvider
  
  init(apiProvider: APIProvider) {
    self.apiProvider = apiProvider
  }
  
  func resolveDomainName(_ domainName: String, isTestnet: Bool) async throws -> Domain {
    let parsedDomainName = parseDomainName(domainName)
    let result = try await apiProvider.api(isTestnet).resolveDomainName(parsedDomainName)
    return Domain(domain: parsedDomainName, friendlyAddress: result)
  }
  
  func loadDomainExpirationDate(_ domainName: String, isTestnet: Bool) async throws -> Date? {
    let parsedDomainName = parseDomainName(domainName)
    return try await apiProvider.api(isTestnet).getDomainExpirationDate(parsedDomainName)
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
