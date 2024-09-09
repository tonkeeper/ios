import Foundation
import TonSwift

public final class WalletNotificationStore: StoreV3<WalletNotificationStore.Event, WalletNotificationStore.State> {
  public typealias State = [Wallet: Bool]
  public enum Event {
    case didUpdateNotificationsIsOn(wallet: Wallet)
  }
  
  private let keeperInfoStore: KeeperInfoStore
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: [:])
  }
  
  public override var initialState: State {
    getState(keeperInfo: keeperInfoStore.getState())
  }

  public func setNotificationIsOn(_ isOn: Bool, wallet: Wallet) async {
    let updatedKeeperInfo = await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return nil }
      let updated = keeperInfo.updateWallet(wallet, notificationsIsOn: isOn)
      return updated
    }
    
    await setState { state in
      var updatedState = state
      updatedState[wallet] = isOn
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      self.sendEvent(.didUpdateNotificationsIsOn(wallet: wallet))
    }
  }
  
  private func getState(keeperInfo: KeeperInfo?) -> State {
    guard let keeperInfo = keeperInfoStore.getState() else {
      return [:]
    }
    var result = State()
    for wallet in keeperInfo.wallets {
      result[wallet] = wallet.notificationSettings.isOn
    }
    return result
  }
}
