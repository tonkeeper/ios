import TKScreenKit
import KeeperCore

struct BackupCheckRecoveryPhraseProvider: TKCheckRecoveryPhraseProvider {
  
  var title: String {
    "Backup Check"
  }
  
  var subtitle: String {
    "Let's see if you've got everything right. Enter words %d, %d, and %d."
  }
  
  var buttonTitle: String {
    "Done"
  }
  
  var phrase: [String] {
    recoveryPhraseController.getRecoveryPhrase()
  }
  
  private let recoveryPhraseController: RecoveryPhraseController
  
  init(recoveryPhraseController: RecoveryPhraseController) {
    self.recoveryPhraseController = recoveryPhraseController
  }
}
