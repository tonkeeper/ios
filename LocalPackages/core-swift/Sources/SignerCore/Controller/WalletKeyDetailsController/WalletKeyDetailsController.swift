import Foundation

public final class WalletKeyDetailsController {
  
  public var didUpdateWalletKey: ((WalletKey) -> Void)?
  
  public private(set) var walletKey: WalletKey
  private let walletKeysStore: WalletKeysStore
  private let mnemonicsRepository: MnemonicsRepository
  
  init(walletKey: WalletKey,
       walletKeysStore: WalletKeysStore,
       mnemonicsRepository: MnemonicsRepository) {
    self.walletKey = walletKey
    self.walletKeysStore = walletKeysStore
    self.mnemonicsRepository = mnemonicsRepository
  }
  
  public func start() {
    _ = walletKeysStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateKeyName(let walletKey):
        observer.walletKey = walletKey
        observer.didUpdateWalletKey?(walletKey)
      case .didDeleteAll:
        Task {
          try? await observer.mnemonicsRepository.deleteAll()
        }
      default:
        break
      }
    }
    didUpdateWalletKey?(walletKey)
  }
  
  public func appLinkDeeplinkUrl(isLocal: Bool) -> URL? {
    LinkDeeplinkGenerator().generateAppDeeplink(
      network: .ton,
      key: walletKey,
      local: isLocal
    )
  }
  
  public func webLinkDeeplinkUrl() -> URL? {
    LinkDeeplinkGenerator().generateWebDeeplink(network: .ton, key: walletKey)
  }
  
  public func deleteKey(password: String) async throws {
    try walletKeysStore.deleteKey(walletKey)
    try await mnemonicsRepository.deleteMnemonic(walletKey: walletKey, password: password)
  }
}
