import Foundation

public protocol SignOutService {
  func signOut() async throws
}

final class SignOutServiceImplementation: SignOutService {
  private let signerInfoRepository: SignerInfoRepository
  private let mnemonicsRepository: MnemonicsRepository
  
  init(signerInfoRepository: SignerInfoRepository,
       mnemonicsRepository: MnemonicsRepository) {
    self.signerInfoRepository = signerInfoRepository
    self.mnemonicsRepository = mnemonicsRepository
  }
  
  func signOut() async throws {
    try signerInfoRepository.removeSignerInfo()
    try await mnemonicsRepository.deleteAll()
  }
}
