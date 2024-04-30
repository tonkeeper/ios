import Foundation

public protocol SetupService {
  var isSetupFinished: Bool { get }
  func setSetupFinished() throws
}

final class SetupServiceImplementation: SetupService {
  let keeperInfoRepository: KeeperInfoRepository
  
  init(keeperInfoRepository: KeeperInfoRepository) {
    self.keeperInfoRepository = keeperInfoRepository
  }
  
  var isSetupFinished: Bool {
    do {
      let keeperInfo = try keeperInfoRepository.getKeeperInfo()
      return keeperInfo.isSetupFinished
    } catch {
      return false
    }
  }
  
  func setSetupFinished() throws {
    let currentKeeperInfo = try keeperInfoRepository.getKeeperInfo()
    let updatedKeeperInfo = currentKeeperInfo.setIsSetupFinished(true)
    try keeperInfoRepository.saveKeeperInfo(updatedKeeperInfo)
  }
}
