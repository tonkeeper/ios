import Foundation
import TonSwift

public final class WalletNotificationStore: StoreV3<WalletNotificationStore.Event, WalletNotificationStore.State> {
  public struct NotificationsState {
    public let isOn: Bool
    public let dapps: [String: Bool]
  }
  
  public typealias State = [Wallet: NotificationsState]
  public enum Event {
    case didUpdateNotificationsIsOn(wallet: Wallet)
    case didUpdateDappNotificationsIsOn(wallet: Wallet)
  }
  
  private let keeperInfoStore: KeeperInfoStore
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: [:])
  }
  
  public override func createInitialState() -> State {
    getState(keeperInfo: keeperInfoStore.getState())
  }

  public func setNotificationIsOn(_ isOn: Bool, wallet: Wallet) async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let updated = keeperInfo.updateWallet(wallet, notificationsIsOn: isOn)
      return updated
    }
    
    await setState { state in
      let walletState = state[wallet]
      let updatedWalletState = NotificationsState(isOn: isOn,
                                                  dapps: walletState?.dapps ?? [:])
      var updatedState = state
      updatedState[wallet] = updatedWalletState
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      self.sendEvent(.didUpdateNotificationsIsOn(wallet: wallet))
    }
  }
  
  public func setNotificationsIsOn(_ isOn: Bool, wallet: Wallet, dappHost: String) async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let updated = keeperInfo.updateWallet(wallet, notificationsIsOn: isOn)
      return updated
    }
    
    await setState { state in
      let walletState = state[wallet]
      var dapps = walletState?.dapps ?? [:]
      dapps[dappHost] = isOn
      let updatedWalletState = NotificationsState(isOn: walletState?.isOn ?? false,
                                                  dapps: dapps)
      var updatedState = state
      updatedState[wallet] = updatedWalletState
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      self.sendEvent(.didUpdateDappNotificationsIsOn(wallet: wallet))
    }
  }
  
  private func getState(keeperInfo: KeeperInfo?) -> State {
    guard let keeperInfo = keeperInfoStore.getState() else {
      return [:]
    }
    var result = State()
    for wallet in keeperInfo.wallets {
      let settings = wallet.notificationSettings
      result[wallet] = NotificationsState(
        isOn: settings.isOn,
        dapps: settings.dapps
      )
    }
    return result
  }
}
