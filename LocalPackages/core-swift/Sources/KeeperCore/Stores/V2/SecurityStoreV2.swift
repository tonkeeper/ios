import Foundation

public final class SecurityStoreV2: Store<SecurityStoreV2.State> {
  public struct State: Equatable {
    public let isBiometryEnable: Bool
    public let isLockScreen: Bool
  }
  
  private let keeperInfoStore: KeeperInfoStore
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    let keeperInfo = keeperInfoStore.getKeeperInfo()
    super.init(state: State(isBiometryEnable: keeperInfo?.securitySettings.isBiometryEnabled ?? false,
                            isLockScreen: keeperInfo?.securitySettings.isLockScreen ?? false))
    keeperInfoStore.addObserver(
      self,
      notifyOnAdded: false) { observer, newState, _ in
        observer.didUpdateKeeperInfo(newState)
      }
  }
  
  public func getIsBiometryEnable() async -> Bool {
    await getState().isBiometryEnable
  }
  
  public func setIsBiometryEnable(_ isBiometryEnable: Bool) async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updatedKeeperInfo = keeperInfo?.setIsBiometryEnabled(isBiometryEnable)
      return updatedKeeperInfo
    }
  }
  
  public func getIsLockScreen() async -> Bool {
    await getState().isLockScreen
  }
  
  public func setIsLockScreen(_ isLockScreen: Bool) async {
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updatedKeeperInfo = keeperInfo?.setIsLockScreen(isLockScreen)
      return updatedKeeperInfo
    }
  }
  
  private func didUpdateKeeperInfo(_ keeperInfo: KeeperInfo?) {
    guard let keeperInfo else { return }
    Task {
      await updateState { state in
        let state = State(
          isBiometryEnable: keeperInfo.securitySettings.isBiometryEnabled,
          isLockScreen: keeperInfo.securitySettings.isLockScreen
        )
        return StateUpdate(newState: state)
      }
    }
  }
}
