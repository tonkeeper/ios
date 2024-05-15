import Foundation
import TonSwift

public final class SendRecipientController {
  
  public var didUpdateRecipient: (() -> Void)?
  public var didUpdateIsValid: ((Bool) -> Void)?
  public var didUpdateIsReadyToContinue: ((Bool) -> Void)?
  
  private var isResolvingRecipient = false
  private var recipientResolveTimer: Timer?
  
  private var recipient: Recipient?
  private let knownAccountsStore: KnownAccountsStore
  private let dnsService: DNSService
  
  init(recipient: Recipient?,
       knownAccountsStore: KnownAccountsStore,
       dnsService: DNSService) {
    self.recipient = recipient
    self.knownAccountsStore = knownAccountsStore
    self.dnsService = dnsService
  }
  
  public func start() {
    didUpdateRecipient?()
    didUpdateIsReadyToContinue?(recipient != nil)
  }
  
  public func getRecipient() -> Recipient? {
    return recipient
  }
  
  public func getRecipientValue() -> String? {
    switch recipient?.recipientAddress {
    case .none:
      return nil
    case .friendly(let friendlyAddress):
      return friendlyAddress.toString()
    case .raw(let address):
      return address.toRaw()
    case .domain(let string):
      return string.domain
    }
  }
  
  public func didUpdateRecipientInput(_ input: String) {
    recipientResolveTimer?.invalidate()
    recipientResolveTimer = nil
    didUpdateIsReadyToContinue?(false)
    didUpdateIsValid?(true)
    
    guard !input.isEmpty else {
      recipient = .none
      didUpdateIsValid?(true)
      return
    }
    let recipientResolveTimer = Timer(timeInterval: 0.75, repeats: false, block: { [weak self] timer in
      timer.invalidate()
      self?.resolveRecipientInput(input)
    })
    RunLoop.main.add(recipientResolveTimer, forMode: .common)
    self.recipientResolveTimer = recipientResolveTimer
  }
  
  func resolveRecipientInput(_ input: String) {
    self.isResolvingRecipient = true
    Task {
      let inputRecipient: Recipient?
      let isValid: Bool
      let knownAccounts = (try? await knownAccountsStore.getKnownAccounts()) ?? []
      if let friendlyAddress = try? FriendlyAddress(string: input) {
        inputRecipient = Recipient(
          recipientAddress: .friendly(
            friendlyAddress
          ),
          isMemoRequired: knownAccounts.first(where: { $0.address == friendlyAddress.address })?.requireMemo ?? false
        )
        isValid = true
      } else if let rawAddress = try? Address.parse(input) {
        inputRecipient = Recipient(
          recipientAddress: .raw(
            rawAddress
          ),
          isMemoRequired: knownAccounts.first(where: { $0.address == rawAddress })?.requireMemo ?? false
        )
        isValid = true
      } else if let domain = try? await dnsService.resolveDomainName(input, isTestnet: false) {
        inputRecipient = Recipient(
          recipientAddress: .domain(domain),
          isMemoRequired: knownAccounts.first(where: { $0.address == domain.friendlyAddress.address })?.requireMemo ?? false
        )
        isValid = true
      } else {
        inputRecipient = nil
        isValid = false
      }
      await MainActor.run {
        self.isResolvingRecipient = false
        self.recipient = inputRecipient
        didUpdateIsValid?(isValid)
        didUpdateIsReadyToContinue?(isValid)
      }
    }
  }
}
