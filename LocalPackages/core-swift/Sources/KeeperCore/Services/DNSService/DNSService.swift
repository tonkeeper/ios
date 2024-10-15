import Foundation
import TonAPI
import TonSwift

public protocol DNSService {
  func resolveDomainName(_ domainName: String, addTonPostfix: Bool, isTestnet: Bool) async throws -> Domain
  func loadDomainExpirationDate(_ domainName: String, isTestnet: Bool) async throws -> Date?
}

public extension DNSService {
  func resolveDomainName(_ domainName: String, isTestnet: Bool) async throws -> Domain {
    try await resolveDomainName(domainName, addTonPostfix: false, isTestnet: isTestnet)
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
  
  func resolveDomainName(_ domainName: String, addTonPostfix: Bool, isTestnet: Bool) async throws -> Domain {
    let resolveName: String = {
      if addTonPostfix {
        return parseDomainName(domainName)
      } else {
        return domainName
      }
    }()
    
    
    let result = try await apiProvider.api(isTestnet).resolveDomainName(resolveName)
    return Domain(domain: resolveName, friendlyAddress: result)
  }
  
  func loadDomainExpirationDate(_ domainName: String, isTestnet: Bool) async throws -> Date? {
    return try await apiProvider.api(isTestnet).getDomainExpirationDate(domainName)
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
