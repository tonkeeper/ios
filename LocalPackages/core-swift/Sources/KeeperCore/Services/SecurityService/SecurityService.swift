import Foundation

public protocol SecurityService {
  var isBiometryTurnedOn: Bool { get }
  func updateBiometry(_ isOn: Bool) throws
}

final class SecurityServiceImplementation: SecurityService {
  let keeperInfoRepository: KeeperInfoRepository
  
  init(keeperInfoRepository: KeeperInfoRepository) {
    self.keeperInfoRepository = keeperInfoRepository
  }
  
  var isBiometryTurnedOn: Bool {
    do {
      let keeperInfo = try keeperInfoRepository.getKeeperInfo()
      return keeperInfo.securitySettings.isBiometryEnabled
    } catch {
      return false
    }
  }
  
  func updateBiometry(_ isOn: Bool) throws {
    let currentKeeperInfo = try keeperInfoRepository.getKeeperInfo()
    let updatedKeeperInfo = currentKeeperInfo.setIsBiometryEnabled(isOn)
    try keeperInfoRepository.saveKeeperInfo(updatedKeeperInfo)
  }
}
