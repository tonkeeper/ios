import Foundation
import CoreComponents

public final class WalletsStoreUpdate {
  typealias ObservationClosure = (Event) -> Void
  enum Event {
    case didAddWallets([Wallet])
    case didUpdateActiveWallet
    case didUpdateWalletMetadata(Wallet, WalletMetaData)
    case didUpdateWalletsOrder
    case didDeleteWallet(Wallet)
    case didDeleteAll
  }
  
  private let walletsService: WalletsService
  
  init(walletsService: WalletsService) {
    self.walletsService = walletsService
  }
  
  public func addWallets(_ wallets: [Wallet]) throws {
    try walletsService.addWallets(wallets)
    observations.values.forEach { $0(.didAddWallets(wallets)) }
  }
  
  public func makeWalletActive(_ wallet: Wallet) throws {
    try walletsService.setWalletActive(wallet)
    observations.values.forEach { $0(.didUpdateActiveWallet) }
  }
  
  public func moveWallet(fromIndex: Int, toIndex: Int) throws {
    try walletsService.moveWallet(fromIndex: fromIndex, toIndex: toIndex)
    observations.values.forEach { $0(.didUpdateWalletsOrder) }
  }
  
  public func updateWallet(_ wallet: Wallet, metaData: WalletMetaData) throws {
    try walletsService.updateWallet(wallet: wallet, metaData: metaData)
    observations.values.forEach { $0(.didUpdateWalletMetadata(wallet, metaData)) }
  }
  
  public func deleteWallet(_ wallet: Wallet) throws {
    let result = try walletsService.deleteWallet(wallet: wallet)
    switch result {
    case .deletedWallet:
      observations.values.forEach { $0(.didDeleteWallet(wallet)) }
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
