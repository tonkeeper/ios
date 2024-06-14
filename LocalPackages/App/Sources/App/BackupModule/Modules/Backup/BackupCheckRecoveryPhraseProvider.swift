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
  
  let phrase: [String]
  
  init(phrase: [String]) {
    self.phrase = phrase
  }
}
