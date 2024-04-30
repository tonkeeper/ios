import Foundation
import TonSwift

actor AddressResolver {
  
  enum Error: Swift.Error {
    case failedToResolve(input: String)
  }
  
  private let dnsService: DNSService
  
  init(dnsService: DNSService) {
    self.dnsService = dnsService
  }
  
  func resolveRecipient(input: String) async throws -> ResolvableAddress {
    if let address = try? Address.parse(input) {
      return ResolvableAddress.Resolved(address)
    }
    
    if let domain = try? await dnsService.resolveDomainName(input) {
      return ResolvableAddress.Domain(domain.domain, domain.friendlyAddress.address)
    }
    
    throw Error.failedToResolve(input: input)
  }
}
