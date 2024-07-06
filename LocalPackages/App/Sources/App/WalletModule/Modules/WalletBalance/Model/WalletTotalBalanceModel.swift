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
  }
  
  var didUpdateState: ((State) -> Void)? {
    didSet {
      Task {
        await self.actor.addTask(block:{
          let activeWallet = await self.walletsStore.getState().activeWallet
          guard let address = try? activeWallet.friendlyAddress else { return }
          let isSecure = await self.secureMode.isSecure
          let balanceState = await self.totalBalanceStore.getState()[address]
          self.update(
            wallet: activeWallet,
            totalBalanceState: balanceState,
            isSecure: isSecure
          )
        })
      }
    }
  }
  
  private let actor = SerialActor<Void>()
  
  private let walletsStore: WalletsStoreV2
  private let totalBalanceStore: TotalBalanceStoreV2
  private let secureMode: SecureMode
  
  init(walletsStore: WalletsStoreV2, 
       totalBalanceStore: TotalBalanceStoreV2,
       secureMode: SecureMode) {
    self.walletsStore = walletsStore
    self.totalBalanceStore = totalBalanceStore
    self.secureMode = secureMode
    
    walletsStore.addObserver(self, notifyOnAdded: true) { observer, walletsState, oldWalletsState in
      Task {
        await observer.didUpdateWalletsState(walletsState,
                                       oldWalletsState)
      }
    }
    totalBalanceStore.addObserver(self, notifyOnAdded: true) { observer, state, oldState in
      Task {
        await observer.didUpdateTotalBalanceState(state,
                                                  oldState)
      }
    }
    secureMode.addObserver(self, notifyOnAdded: false) { observer, newState, _ in
      Task {
        await observer.didUpdateSecureMode(newState)
      }
    }
  }
  
  private func didUpdateWalletsState(_ walletsState: WalletsState,
                                     _ oldWalletsState: WalletsState?) async {
    await actor.addTask {
      guard walletsState.activeWallet != oldWalletsState?.activeWallet else { return }
      guard let address = try? walletsState.activeWallet.friendlyAddress else { return }
      let isSecure = await self.secureMode.isSecure
      let totalBalanceState = await self.totalBalanceStore.getState()[address]
      self.update(
        wallet: walletsState.activeWallet,
        totalBalanceState: totalBalanceState,
        isSecure: isSecure
      )
    }
  }
  
  private func didUpdateTotalBalanceState(_ totalBalances: [FriendlyAddress: TotalBalanceState],
                                          _ oldTotalBalances: [FriendlyAddress: TotalBalanceState]?) async {
    await actor.addTask {
      let wallet = await self.walletsStore.getState().activeWallet
      guard let address = try? wallet.friendlyAddress else { return }
      let isSecure = await self.secureMode.isSecure
      guard totalBalances[address] != oldTotalBalances?[address] else { return }
      self.update(wallet: wallet,
                  totalBalanceState: totalBalances[address],
                  isSecure: isSecure)
    }
  }
  
  private func didUpdateSecureMode(_ isSecure: Bool) async {
    await actor.addTask {
      let activeWallet = await self.walletsStore.getState().activeWallet
      guard let address = try? activeWallet.friendlyAddress else { return }
      let isSecure = await self.secureMode.isSecure
      let totalBalanceState = await self.totalBalanceStore.getState()[address]
      self.update(wallet: activeWallet,
                  totalBalanceState: totalBalanceState,
                  isSecure: isSecure)
    }
  }
  
  private func update(wallet: Wallet, 
                      totalBalanceState: TotalBalanceState?,
                      isSecure: Bool) {
    guard let address = try? wallet.friendlyAddress else { return }
    
    let state = State(
      wallet: wallet,
      address: address,
      totalBalanceState: totalBalanceState,
      isSecure: isSecure
    )
    didUpdateState?(state)
  }
}
