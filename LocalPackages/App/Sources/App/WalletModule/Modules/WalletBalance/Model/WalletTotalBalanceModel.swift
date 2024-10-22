import Foundation
import KeeperCore
import TKCore
import TonSwift

final class WalletTotalBalanceModel {
  
  struct State {
    let wallet: Wallet
    let address: FriendlyAddress
    let totalBalanceState: TotalBalanceState?
    let isSecure: Bool
    let backgroundUpdateState: BackgroundUpdateStore.ConnectionState
    let isLoadingBalance: Bool
  }
  
  var didUpdateState: ((State) -> Void)?
  
  private let walletsStore: WalletsStore
  private let totalBalanceStore: TotalBalanceStore
  private let appSettingsStore: AppSettingsStore
  private let backgroundUpdateStore: BackgroundUpdateStore
  private let balanceLoader: BalanceLoader
  private let updateQueue: DispatchQueue
  
  init(walletsStore: WalletsStore,
       totalBalanceStore: TotalBalanceStore,
       appSettingsStore: AppSettingsStore,
       backgroundUpdateStore: BackgroundUpdateStore,
       balanceLoader: BalanceLoader,
       updateQueue: DispatchQueue) {
    self.walletsStore = walletsStore
    self.totalBalanceStore = totalBalanceStore
    self.appSettingsStore = appSettingsStore
    self.backgroundUpdateStore = backgroundUpdateStore
    self.balanceLoader = balanceLoader
    self.updateQueue = updateQueue
    
    walletsStore.addObserver(self) { observer, event in
      observer.didGetWalletsStoreEvent(event)
    }
    
    totalBalanceStore.addObserver(self) { observer, event in
      observer.didGetTotalBalanceStoreEvent(event)
    }
    
    appSettingsStore.addObserver(self) { observer, event in
      observer.didGetAppSettingsStoreEvent(event)
    }
    
    backgroundUpdateStore.addObserver(self) { observer, event in
      observer.didGetBackgroundUpdateStoreEvent(event)
    }
    
    balanceLoader.addUpdateObserver(self) { observer, wallet in
      observer.didGetBalanceLoaderEvent(wallet)
    }
  }
  
  func getState() throws -> State {
    let activeWallet = try walletsStore.activeWallet
    let isSecureMode = appSettingsStore.state.isSecureMode
    let totalBalanceState = totalBalanceStore.state[activeWallet]
//    let backgroundUpdateState = backgroundUpdateStore.state[activeWallet] ?? .connecting
    let isLoadingBalance = balanceLoader.isLoadingBalance(wallet: activeWallet)
    return try createState(
      wallet: activeWallet,
      isSecureMode: isSecureMode,
      totalBalanceState: totalBalanceState,
      backgroundUpdateState: .connected,
      isLoadingBalance: isLoadingBalance
    )
  }
  
  private func didGetBalanceLoaderEvent(_ wallet: Wallet) {
    updateQueue.async { [weak self] in
      guard let activeWallet = try? self?.walletsStore.activeWallet,
      wallet == activeWallet else { return }
      self?.updateModel()
    }
  }
  
  private func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
    updateQueue.async { [weak self] in
      switch event {
      case .didChangeActiveWallet:
        self?.updateModel()
      default: break
      }
    }
  }
  
  private func didGetTotalBalanceStoreEvent(_ event: TotalBalanceStore.Event) {
    updateQueue.async { [weak self] in
      switch event {
      case .didUpdateTotalBalance(let wallet):
        guard let activeWallet = try? self?.walletsStore.activeWallet,
        wallet == activeWallet else { return }
        self?.updateModel()
      }
    }
  }
  
  private func didGetAppSettingsStoreEvent(_ event: AppSettingsStore.Event) {
    updateQueue.async { [weak self] in
      self?.updateModel()
    }
  }
  
  private func didGetBackgroundUpdateStoreEvent(_ event: BackgroundUpdateStore.Event) {
    updateQueue.async { [weak self] in
      self?.updateModel()
    }
  }
  
  private func updateModel() {
    guard let state = try? getState() else { return }
    didUpdateState?(state)
  }
  
  private func createState(wallet: Wallet,
                           isSecureMode: Bool,
                           totalBalanceState: TotalBalanceState?,
                           backgroundUpdateState: BackgroundUpdateStore.ConnectionState,
                           isLoadingBalance: Bool) throws -> State {
    return State(
      wallet: wallet,
      address: try wallet.friendlyAddress,
      totalBalanceState: totalBalanceState,
      isSecure: isSecureMode,
      backgroundUpdateState: backgroundUpdateState,
      isLoadingBalance: isLoadingBalance
    )
  }
}
