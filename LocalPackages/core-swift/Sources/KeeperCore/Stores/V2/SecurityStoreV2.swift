import Foundation

public final class SecurityStoreV2: Store<SecurityStoreV2.State> {
  public struct State: Equatable {
    public let isBiometryEnable: Bool
  }
  
  private let keeperInfoStore: KeeperInfoStore
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: State(isBiometryEnable: false))
    keeperInfoStore.addObserver(
      self,
      notifyOnAdded: true) { observer, newState, _ in
        observer.didUpdateKeeperInfo(newState)
      }
  }
  
  public func getIsBiometryEnable() async -> Bool {
    await getState().isBiometryEnable
  }
  
  public func setIsBiometryEnable(_ isBiometryEnable: Bool) async {
    await updateState { _ in StateUpdate(newState: State(isBiometryEnable: isBiometryEnable)) }
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updatedKeeperInfo = keeperInfo?.setIsBiometryEnabled(isBiometryEnable)
      return updatedKeeperInfo
    }
  }
  
  private func didUpdateKeeperInfo(_ keeperInfo: KeeperInfo?) {
    guard let keeperInfo else { return }
    Task {
      await updateState { state in
        let state = State(isBiometryEnable: keeperInfo.securitySettings.isBiometryEnabled)
        return StateUpdate(newState: state)
      }
    }
  }
}
