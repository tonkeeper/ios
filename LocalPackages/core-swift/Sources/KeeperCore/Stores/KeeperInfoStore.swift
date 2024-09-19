import Foundation

public final class KeeperInfoStore: StoreV3<KeeperInfoStore.Event, KeeperInfo?> {
  public enum Event {
    case didUpdateKeeperInfo(KeeperInfo?)
  }
  
  private let keeperInfoRepository: KeeperInfoRepository
  
  init(keeperInfoRepository: KeeperInfoRepository) {
    self.keeperInfoRepository = keeperInfoRepository
    super.init(state: nil)
  }
  
  public override var initialState: KeeperInfo? {
    try? self.keeperInfoRepository.getKeeperInfo()
  }

  @discardableResult
  public func updateKeeperInfo(_ block: @escaping (KeeperInfo?) -> KeeperInfo?) async -> KeeperInfo? {
    let newState = await setState { [keeperInfoRepository] current in
      if let updated = block(current) {
        try? keeperInfoRepository.saveKeeperInfo(updated)
        return StateUpdate(newState: updated)
      } else {
        try? keeperInfoRepository.removeKeeperInfo()
        return StateUpdate(newState: nil)
      }
    } notify: { state in
      self.sendEvent(.didUpdateKeeperInfo(state))
    }
    return newState
  }
}
