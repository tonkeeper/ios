import Foundation

public final class KeeperInfoStore: Store<KeeperInfoStore.Event, KeeperInfo?> {
  public enum Event {
    case didUpdateKeeperInfo(KeeperInfo?)
  }
  
  private let keeperInfoRepository: KeeperInfoRepository
  
  init(keeperInfoRepository: KeeperInfoRepository) {
    self.keeperInfoRepository = keeperInfoRepository
    super.init(state: nil)
  }
  
  public override func createInitialState() -> KeeperInfo? {
    try? self.keeperInfoRepository.getKeeperInfo()
  }
  
  public func updateKeeperInfo(_ updateBlock: @escaping (KeeperInfo?) -> KeeperInfo?,
                               completion: ((KeeperInfo?) -> Void)? = nil) {
    updateState { [keeperInfoRepository] keeperInfo in
      guard let newState = updateBlock(keeperInfo) else {
        try? keeperInfoRepository.removeKeeperInfo()
        return StateUpdate(newState: nil)
      }
      try? keeperInfoRepository.saveKeeperInfo(newState)
      return StateUpdate(newState: newState)
    } completion: { [weak self] updatedState in
      self?.sendEvent(.didUpdateKeeperInfo(updatedState))
      completion?(updatedState)
    }
  }
  
  public func updateKeeperInfo(_ updateBlock: @escaping (KeeperInfo?) -> KeeperInfo?) async -> KeeperInfo? {
    return await withCheckedContinuation { continuation in
      updateKeeperInfo(updateBlock) { updatedState in
        continuation.resume(returning: updatedState)
      }
    }
  }
}
