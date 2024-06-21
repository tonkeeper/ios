import Foundation

public final class KeeperInfoStore: Store<KeeperInfo?> {
  
  private let keeperInfoRepository: KeeperInfoRepository
  
  init(keeperInfoRepository: KeeperInfoRepository) {
    self.keeperInfoRepository = keeperInfoRepository
    super.init(
      item: nil
    )
    Task {
      await updateItem { _ in
        return try? keeperInfoRepository.getKeeperInfo()
      }
    }
  }
  
  func updateKeeperInfo(_ block: @escaping (KeeperInfo?) -> KeeperInfo?) async {
    await updateItem { [keeperInfoRepository] keeperInfo in
      let updated = block(keeperInfo)
      if let updated {
        try? keeperInfoRepository.saveKeeperInfo(updated)
      } else {
        try? keeperInfoRepository.removeKeeperInfo()
      }
      return updated
    }
  }
}
