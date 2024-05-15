import Foundation

public protocol SignOutService {
  func signOut() throws
}

final class SignOutServiceImplementation: SignOutService {
  private let signerInfoRepository: SignerInfoRepository
  private let mnemonicsRepository: MnemonicsRepository
  
  init(signerInfoRepository: SignerInfoRepository,
       mnemonicsRepository: MnemonicsRepository) {
    self.signerInfoRepository = signerInfoRepository
    self.mnemonicsRepository = mnemonicsRepository
  }
  
  func signOut() throws {
    try signerInfoRepository.removeSignerInfo()
    try mnemonicsRepository.deleteAll()
  }
}
