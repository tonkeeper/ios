import Foundation

public final class KeeperInfoStoreV3: StoreV3<KeeperInfoStoreV3.Event, KeeperInfo?> {
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

  public func updateKeeperInfo(_ block: @escaping (KeeperInfo?) -> KeeperInfo?) async {
    var updatedKeeperInfo: KeeperInfo?
    await setState { [keeperInfoRepository] current in
      if let updated = block(current) {
        try? keeperInfoRepository.saveKeeperInfo(updated)
        updatedKeeperInfo = updated
        return StateUpdate(newState: updated)
      } else {
        try? keeperInfoRepository.removeKeeperInfo()
        updatedKeeperInfo = nil
        return StateUpdate(newState: nil)
      }
    } notify: {
      self.sendEvent(.didUpdateKeeperInfo(updatedKeeperInfo))
    }
  }
}
