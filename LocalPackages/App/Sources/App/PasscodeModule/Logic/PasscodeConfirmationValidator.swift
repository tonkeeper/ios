import Foundation
import KeeperCore

struct PasscodeConfirmationValidator: PasscodeInputValidator {
  
  private let mnemonicsRepository: MnemonicsRepository
  
  init(mnemonicsRepository: MnemonicsRepository) {
    self.mnemonicsRepository = mnemonicsRepository
  }
  
  func validate(passcode: String) async -> PasscodeInputValidationResult {
    if await mnemonicsRepository.checkIfPasswordValid(passcode) {
      return .success
    } else {
      return .failed
    }
  }
}
