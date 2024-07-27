import Foundation

public final class KeeperInfoStore: StoreUpdated<KeeperInfo?> {
  
  private let keeperInfoRepository: KeeperInfoRepository
  
  init(keeperInfoRepository: KeeperInfoRepository) {
    self.keeperInfoRepository = keeperInfoRepository
    super.init(state: nil)
  }
  
  public func updateKeeperInfo(_ block: @escaping (KeeperInfo?) -> KeeperInfo?, completion: (() -> Void)?) {
    updateState { [keeperInfoRepository] keeperInfo in
      let updated = block(keeperInfo)
      if let updated {
        try? keeperInfoRepository.saveKeeperInfo(updated)
      } else {
        try? keeperInfoRepository.removeKeeperInfo()
      }
      return StateUpdate(newState: updated)
    } completion: {
      completion?()
    }
  }
  
  public func updateKeeperInfo(_ block: @escaping (KeeperInfo?) -> KeeperInfo?) async {
    await updateState { [keeperInfoRepository] keeperInfo in
      let updated = block(keeperInfo)
      if let updated {
        try? keeperInfoRepository.saveKeeperInfo(updated)
      } else {
        try? keeperInfoRepository.removeKeeperInfo()
      }
      return StateUpdate(newState: updated)
    }
  }
  
  public override func getInitialState() -> KeeperInfo? {
    try? self.keeperInfoRepository.getKeeperInfo()
  }
}
