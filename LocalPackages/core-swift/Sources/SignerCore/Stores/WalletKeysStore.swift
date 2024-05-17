import Foundation

public final class WalletKeysStore {
  typealias ObservationClosure = (Event) -> Void
  enum Event {
    case didAddKey(WalletKey)
    case didUpdateKeyName(WalletKey)
    case didDeleteKey(WalletKey)
    case didDeleteAll
  }
  
  private let walletKeysService: WalletKeysService
  
  init(walletKeysService: WalletKeysService) {
    self.walletKeysService = walletKeysService
  }
  
  public func getWalletKeys() -> [WalletKey] {
    do {
      return try walletKeysService.getKeys()
    } catch {
      return []
    }
  }
  
  public func addWalletKey(_ walletKey: WalletKey) throws {
    try walletKeysService.addKey(walletKey)
    observations.forEach { $0.value(.didAddKey(walletKey)) }
  }
  
  public func updateWalletKeyName(_ walletKey: WalletKey, name: String) throws {
    let updatedWalletKey = try walletKeysService.updateKeyName(walletKey, name: name)
    observations.forEach { $0.value(.didUpdateKeyName(updatedWalletKey)) }
  }
  
  public func deleteKey(_ key: WalletKey) throws {
    let result = try walletKeysService.deleteKey(key)
    switch result {
    case .deletedKey:
      observations.values.forEach { $0(.didDeleteKey(key)) }
    case .deletedAll:
      observations.values.forEach { $0(.didDeleteAll) }
    }
  }
  
  private var observations = [UUID: ObservationClosure]()
  
  func addEventObserver<T: AnyObject>(_ observer: T,
                                      closure: @escaping (T, Event) -> Void) -> ObservationToken {
    let id = UUID()
    let eventHandler: (Event) -> Void = { [weak self, weak observer] event in
      guard let self else { return }
      guard let observer else {
        observations.removeValue(forKey: id)
        return
      }
      
      closure(observer, event)
    }
    observations[id] = eventHandler
    
    return ObservationToken { [weak self] in
      guard let self else { return }
      observations.removeValue(forKey: id)
    }
  }
}
