import Foundation
import CoreComponents

public final class WalletsStore {
  public typealias ObservationClosure = (Event) -> Void
  public enum Event {
    case didAddWallets([Wallet])
    case didUpdateActiveWallet
    case didUpdateWalletMetadata(Wallet)
    case didUpdateWalletsOrder
    case didUpdateWalletBackupState(Wallet)
    case didDeleteWallet(Wallet)
    case didDeleteLastWallet
  }
  
  public private(set) var wallets: [Wallet]
  public private(set) var activeWallet: Wallet
  
  private var walletsStoreUpdateObservationToken: ObservationToken?
  private var backupStoreObservationToken: ObservationToken?
  
  private let walletsService: WalletsService
  private let backupStore: BackupStore
  private let walletsStoreUpdate: WalletsStoreUpdate
  
  init(wallets: [Wallet],
       activeWallet: Wallet,
       walletsService: WalletsService,
       backupStore: BackupStore,
       walletsStoreUpdate: WalletsStoreUpdate) {
    self.wallets = wallets
    self.activeWallet = activeWallet
    self.walletsService = walletsService
    self.backupStore = backupStore
    self.walletsStoreUpdate = walletsStoreUpdate
    
    self.walletsStoreUpdateObservationToken = walletsStoreUpdate.addEventObserver(self) { observer, event in
      observer.didGetWalletsStoreUpdateEvent(event)
    }
    
    self.backupStoreObservationToken = backupStore.addEventObserver(self) { observer, event in
      observer.didGetBackupStoreEvent(event)
    }
  }
  
  deinit {
    walletsStoreUpdateObservationToken?.cancel()
  }

  private var observations = [UUID: ObservationClosure]()
  
  public func addEventObserver<T: AnyObject>(_ observer: T,
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

private extension WalletsStore {
  func didGetWalletsStoreUpdateEvent(_ event: WalletsStoreUpdate.Event) {
    switch event {
    case .didAddWallets(let addedWallets):
      do {
        let wallets = try walletsService.getWallets()
        let activeWallet = try walletsService.getActiveWallet()
        self.wallets = wallets
        self.activeWallet = activeWallet
        observations.values.forEach { $0(.didAddWallets(addedWallets)) }
      } catch {
        print("Log: failed to update WalletsStore after add wallets: \(addedWallets), error: \(error)")
      }
    case .didUpdateActiveWallet:
      do {
        self.activeWallet = try walletsService.getActiveWallet()
        observations.values.forEach { $0(.didUpdateActiveWallet) }
      } catch {
        print("Log: failed to update WalletsStore after active wallet update, error: \(error)")
      }
    case .didUpdateWalletMetadata(let wallet, _):
      do {
        let wallets = try walletsService.getWallets()
        let activeWallet = try walletsService.getActiveWallet()
        self.wallets = wallets
        self.activeWallet = activeWallet
        guard let updatedWallet = self.wallets.first(where: { $0.identity == wallet.identity }) else {
          print("Log: Failed to get updated wallet after update wallets metadata \(wallet)")
          return
        }
        observations.values.forEach { $0(.didUpdateWalletMetadata(updatedWallet)) }
      } catch {
        print("Log: failed to update WalletsStore after update wallets metadata \(wallet), error: \(error)")
      }
    case .didUpdateWalletsOrder:
      do {
        let wallets = try walletsService.getWallets()
        let activeWallet = try walletsService.getActiveWallet()
        self.wallets = wallets
        self.activeWallet = activeWallet
        observations.values.forEach { $0(.didUpdateWalletsOrder) }
      } catch {
        print("Log: failed to update WalletsStore after update wallets order, error: \(error)")
      }
    case .didDeleteWallet(let wallet):
      do {
        let wallets = try walletsService.getWallets()
        let activeWallet = try walletsService.getActiveWallet()
        self.wallets = wallets
        self.activeWallet = activeWallet
        observations.values.forEach { $0(.didUpdateActiveWallet) }
        observations.values.forEach { $0(.didDeleteWallet(wallet)) }
      } catch {
        print("Log: failed to update WalletsStore after wallet delete \(wallet), error: \(error)")
      }
    case .didDeleteAll:
      observations.values.forEach { $0(.didDeleteLastWallet) }
    }
  }
  
  func didGetBackupStoreEvent(_ event: BackupStore.Event) {
    switch event {
    case .didBackup(let wallet):
      do {
        let wallets = try walletsService.getWallets()
        let activeWallet = try walletsService.getActiveWallet()
        self.wallets = wallets
        self.activeWallet = activeWallet
        guard let updatedWallet = self.wallets.first(where: { $0.identity == wallet.identity }) else {
          print("Log: Failed to get updated wallet after wallet backup \(wallet)")
          return
        }
        observations.values.forEach { $0(.didUpdateWalletBackupState(updatedWallet)) }
      } catch {
        print("Log: Failed to update WalletsStore wallet after wallet backup \(wallet), error: \(error)")
      }
    }
  }
}

