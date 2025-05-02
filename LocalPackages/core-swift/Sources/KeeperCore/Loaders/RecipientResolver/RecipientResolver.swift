import Foundation
import TonSwift

public protocol RecipientResolver {
  func resolverRecipient(string: String, isTestnet: Bool) async throws -> Recipient
  func resolverTonRecipient(string: String, isTestnet: Bool) async throws -> TonRecipient
}

public struct RecipientResolverImplementation: RecipientResolver {
  
  public enum Error: Swift.Error {
    case failedResolve(string: String)
    case incorrectNet(sender: Network, recipient: Network)
  }
  
  private let knownAccountsProvider: KnownAccountsProvider
  private let dnsService: DNSService
  
  init(knownAccountsProvider: KnownAccountsProvider,
       dnsService: DNSService) {
    self.knownAccountsProvider = knownAccountsProvider
    self.dnsService = dnsService
  }
  
  public func resolverRecipient(string: String, isTestnet: Bool) async throws -> Recipient {
    if let tronRecipient = resolveTronRecipient(string: string) {
      return .tron(tronRecipient)
    }
    
    return .ton(try await resolverTonRecipient(string: string, isTestnet: isTestnet))
  }
  
  public func resolverTonRecipient(string: String, isTestnet: Bool) async throws -> TonRecipient {
    
    if let friendlyAddress = try? FriendlyAddress(string: string) {
      guard friendlyAddress.isTestOnly == isTestnet else {
        throw Error.incorrectNet(sender: isTestnet ? .testnet : .mainnet,
                                 recipient: friendlyAddress.isTestOnly ? .testnet : .mainnet)
      }
      return TonRecipient(
        recipientAddress: .friendly(friendlyAddress),
        isMemoRequired: await isMemoRequired(for: friendlyAddress.address)
      )
    } else if let address = try? Address.parse(string) {
      return TonRecipient(
        recipientAddress: .raw(address),
        isMemoRequired: await isMemoRequired(for: address)
      )
    } else if let domain = try? await dnsService.resolveDomainName(string,
                                                                   isTestnet: isTestnet) {
      return TonRecipient(
        recipientAddress: .domain(domain),
        isMemoRequired: await isMemoRequired(for: domain.friendlyAddress.address)
      )
    } else {
      throw Error.failedResolve(string: string)
    }
  }
  
  private func resolveTronRecipient(string: String) -> TronRecipient? {
    try? TronRecipient(address: string)
  }
  
  private func isMemoRequired(for address: Address) async -> Bool {
    let knownAccounts = await knownAccountsProvider.getKnownAccounts()
    
    if let knownAccount = knownAccounts.first(where: { $0.address.toRaw() == address.toRaw() }) {
      return knownAccount.requireMemo
    } else {
      return false
    }
  }
}
