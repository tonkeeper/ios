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
    let backgroundUpdateState: BackgroundUpdateStoreV3.State
    let isLoadingBalance: Bool
  }
  
  var didUpdateState: ((State) -> Void)?
  
  private let actor = SerialActor<Void>()
  
  private let walletsStore: WalletsStoreV3
  private let totalBalanceStore: TotalBalanceStore
  private let appSettingsStore: AppSettingsV3Store
  private let backgroundUpdateStore: BackgroundUpdateStoreV3
  private let stateLoader: WalletStateLoader
  
  init(walletsStore: WalletsStoreV3,
       totalBalanceStore: TotalBalanceStore,
       appSettingsStore: AppSettingsV3Store,
       backgroundUpdateStore: BackgroundUpdateStoreV3,
       stateLoader: WalletStateLoader) {
    self.walletsStore = walletsStore
    self.totalBalanceStore = totalBalanceStore
    self.appSettingsStore = appSettingsStore
    self.backgroundUpdateStore = backgroundUpdateStore
    self.stateLoader = stateLoader
    
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
    
    stateLoader.addObserver(self) { observer, event in
      observer.didGetStateLoaderEvent(event)
    }
  }
  
  func getState() throws -> State {
    let activeWallet = try walletsStore.getActiveWallet()
    let isSecureMode = appSettingsStore.getState().isSecureMode
    let totalBalanceState = totalBalanceStore.getState()[activeWallet]
    let backgroundUpdateState = backgroundUpdateStore.getState()
    let isLoadingBalance = stateLoader.getState().balanceLoadTasks[activeWallet] != nil
    return try createState(
      wallet: activeWallet,
      isSecureMode: isSecureMode,
      totalBalanceState: totalBalanceState,
      backgroundUpdateState: backgroundUpdateState,
      isLoadingBalance: isLoadingBalance
    )
  }
  
  private func didGetWalletsStoreEvent(_ event: WalletsStoreV3.Event) {
    Task {
      switch event {
      case .didChangeActiveWallet:
        await self.actor.addTask(block: { try await self.updateModel() })
      default: break
      }
    }
  }
  
  private func didGetTotalBalanceStoreEvent(_ event: TotalBalanceStore.Event) {
    Task {
      switch event {
      case .didUpdateTotalBalance(_, let wallet):
        switch await walletsStore.getState() {
        case .empty: break
        case .wallets(let state):
          guard state.activeWalelt == wallet else { return }
          await self.actor.addTask(block: { try await self.updateModel() })
        }
      }
    }
  }
  
  private func didGetAppSettingsStoreEvent(_ event: AppSettingsV3Store.Event) {
    Task {
      await self.actor.addTask(block: { try await self.updateModel() })
    }
  }
  
  private func didGetBackgroundUpdateStoreEvent(_ event: BackgroundUpdateStoreV3.Event) {
    Task {
      await self.actor.addTask(block: { try await self.updateModel() })
    }
  }
  
  private func didGetStateLoaderEvent(_ event: WalletStateLoader.Event) {
    Task {
      switch await walletsStore.getState() {
      case .empty: break
      case .wallets(let state):
        await self.actor.addTask(block: { try await self.updateModel() })
        switch event {
        case .didEndLoadBalance(let wallet):
          guard state.activeWalelt == wallet else { return }
          await self.actor.addTask(block: { try await self.updateModel() })
        case .didStartLoadBalance(let wallet):
          guard state.activeWalelt == wallet else { return }
          await self.actor.addTask(block: { try await self.updateModel() })
        default: break
        }
      }
    }
  }
  
  private func updateModel() async throws {
    let walletsStoreState = await walletsStore.getState()
    switch walletsStoreState {
    case .empty: break
    case .wallets(let walletsState):
      let isSecureMode = await appSettingsStore.getState().isSecureMode
      let totalBalance = await totalBalanceStore.getState()[walletsState.activeWalelt]
      let backgroundUpdateState = await backgroundUpdateStore.getState()
      let isLoadingBalance = await {
        let state = await stateLoader.getState()
        return state.balanceLoadTasks[walletsState.activeWalelt] != nil
      }()
      let state = try createState(
        wallet: walletsState.activeWalelt,
        isSecureMode: isSecureMode,
        totalBalanceState: totalBalance,
        backgroundUpdateState: backgroundUpdateState,
        isLoadingBalance: isLoadingBalance
      )
      didUpdateState?(state)
    }
  }
  
  private func createState(wallet: Wallet,
                           isSecureMode: Bool,
                           totalBalanceState: TotalBalanceState?,
                           backgroundUpdateState: BackgroundUpdateStoreV3.State,
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
