import Foundation
import TonSwift

public protocol RecipientResolver {
  func resolverRecipient(string: String, isTestnet: Bool) async throws -> Recipient
}

public struct RecipientResolverImplementation: RecipientResolver {
  
  public enum Error: Swift.Error {
    case failedResolve(string: String)
  }
  
  private let knownAccountsStore: KnownAccountsStore
  private let dnsService: DNSService
  
  init(knownAccountsStore: KnownAccountsStore, 
       dnsService: DNSService) {
    self.knownAccountsStore = knownAccountsStore
    self.dnsService = dnsService
  }
  
  public func resolverRecipient(string: String, isTestnet: Bool) async throws -> Recipient {
    
    if let friendlyAddress = try? FriendlyAddress(string: string) {
      return Recipient(
        recipientAddress: .friendly(friendlyAddress),
        isMemoRequired: await isMemoRequired(for: friendlyAddress.address)
      )
    } else if let address = try? Address.parse(string) {
      return Recipient(
        recipientAddress: .raw(address),
        isMemoRequired: await isMemoRequired(for: address)
      )
    } else if let domain = try? await dnsService.resolveDomainName(string,
                                                                   isTestnet: isTestnet) {
      return Recipient(
        recipientAddress: .domain(domain),
        isMemoRequired: await isMemoRequired(for: domain.friendlyAddress.address)
      )
    } else {
      throw Error.failedResolve(string: string)
    }
  }
  
  private func isMemoRequired(for address: Address) async -> Bool {
    let knownAccounts: [KnownAccount]
    do {
      knownAccounts = try await knownAccountsStore.getKnownAccounts()
    } catch {
      knownAccounts = []
    }
    
    if let knownAccount = knownAccounts.first(where: { $0.address == address }) {
      return knownAccount.requireMemo
    } else {
      return false
    }
  }
}
