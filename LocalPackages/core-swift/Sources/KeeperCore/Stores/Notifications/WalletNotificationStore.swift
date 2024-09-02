import Foundation
import TonSwift

public final class WalletNotificationStore: StoreUpdated<[FriendlyAddress: Bool]> {
  
  private let keeperInfoStore: KeeperInfoStore
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: [:])
    keeperInfoStore.addObserver(
      self,
      notifyOnAdded: false) { observer, newState, _ in
        observer.updateState { _ in
          let state = observer.getState(keeperInfo: newState)
          return StateUpdate(newState: state)
        }
      }
  }
  
  public override func getInitialState() -> [FriendlyAddress : Bool] {
    return getState(keeperInfo: keeperInfoStore.getState())
  }
  
  public func setNotificationIsOn(_ isOn: Bool, wallet: Wallet) async {
    guard let address = try? wallet.friendlyAddress else { return }
    await updateState { state in
      var updatedState = state
      updatedState[address] = isOn
      return StateUpdate(newState: updatedState)
    }
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      guard let keeperInfo else { return keeperInfo }
      let updatedWallet = Wallet(
        id: wallet.id,
        identity: wallet.identity,
        metaData: wallet.metaData,
        setupSettings: wallet.setupSettings,
        notificationSettings: NotificationSettings(isOn: isOn),
        backupSettings: wallet.backupSettings,
        addressBook: wallet.addressBook
      )
      var wallets = keeperInfo.wallets
      guard let index = wallets.firstIndex(where: { $0.id == wallet.id }) else { return keeperInfo }
      wallets.remove(at: index)
      wallets.insert(updatedWallet, at: index)
      var updatedKeeperInfo = keeperInfo.setWallets(wallets)
      return updatedKeeperInfo
    }
  }
  
  private func getState(keeperInfo: KeeperInfo?) -> [FriendlyAddress: Bool] {
    guard let keeperInfo = keeperInfoStore.getState() else {
      return [:]
    }
    var result = [FriendlyAddress: Bool]()
    for wallet in keeperInfo.wallets {
      guard let address = try? wallet.friendlyAddress else { continue }
      result[address] = wallet.notificationSettings.isOn
    }
    return result
  }
}
