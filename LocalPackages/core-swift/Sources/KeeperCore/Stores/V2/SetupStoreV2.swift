import Foundation

public final class SetupStoreV2: Store<SetupStoreV2.State> {
  public struct State: Equatable {
    public let isSetupFinished: Bool
  }
  
  private let keeperInfoStore: KeeperInfoStore
  
  init(keeperInfoStore: KeeperInfoStore) {
    self.keeperInfoStore = keeperInfoStore
    super.init(state: State(isSetupFinished: false))
    keeperInfoStore.addObserver(
      self,
      notifyOnAdded: true) { observer, newState, _ in
        observer.didUpdateKeeperInfo(newState)
      }
  }
  
  public func getIsSetupFinished() async -> Bool {
    await getState().isSetupFinished
  }
  
  public func setIsSetupFinished(_ isSetupFinished: Bool) async {
    await updateState { _ in StateUpdate(newState: State(isSetupFinished: isSetupFinished)) }
    await keeperInfoStore.updateKeeperInfo { keeperInfo in
      let updatedKeeperInfo = keeperInfo?.setIsSetupFinished(isSetupFinished)
      return updatedKeeperInfo
    }
  }
  
  private func didUpdateKeeperInfo(_ keeperInfo: KeeperInfo?) {
    guard let keeperInfo else { return }
    Task {
      await updateState { state in
        let state = State(isSetupFinished: keeperInfo.isSetupFinished)
        return StateUpdate(newState: state)
      }
    }
  }
}
