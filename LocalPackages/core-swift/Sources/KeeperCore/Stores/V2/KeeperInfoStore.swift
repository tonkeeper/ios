import Foundation

public final class KeeperInfoStore: Store<KeeperInfo?> {
  
  private let keeperInfoRepository: KeeperInfoRepository
  
  init(keeperInfoRepository: KeeperInfoRepository) {
    self.keeperInfoRepository = keeperInfoRepository
    super.init(state: nil)
    self.setInitialState()
  }
  
  func getKeeperInfo() -> KeeperInfo? {
    getState()
  }
  
  func getKeeperInfo() async -> KeeperInfo? {
    await getState()
  }
  
  func updateKeeperInfo(_ block: @escaping (KeeperInfo?) -> KeeperInfo?) async {
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
  
  private func setInitialState() {
    let state = getState()
    Task {
      await updateState { _ in
        StateUpdate(newState: try? self.keeperInfoRepository.getKeeperInfo())
      }
    }
  }
}
