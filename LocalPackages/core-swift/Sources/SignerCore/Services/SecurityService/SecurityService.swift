import Foundation

public protocol SecurityService {
  var isBiometryTurnedOn: Bool { get }
  func updateBiometry(_ isOn: Bool) throws
}

final class SecurityServiceImplementation: SecurityService {
  let signerInfoRepository: SignerInfoRepository
  
  init(signerInfoRepository: SignerInfoRepository) {
    self.signerInfoRepository = signerInfoRepository
  }
  
  var isBiometryTurnedOn: Bool {
    do {
      let signerInfo = try signerInfoRepository.getSignerInfo()
      return signerInfo.securitySettings.isBiometryEnabled
    } catch {
      return false
    }
  }
  
  func updateBiometry(_ isOn: Bool) throws {
    let currentSignerInfo = try signerInfoRepository.getSignerInfo()
    let updatedSignerInfo = currentSignerInfo.setIsBiometryEnabled(isOn)
    try signerInfoRepository.saveSignerInfo(updatedSignerInfo)
  }
}
