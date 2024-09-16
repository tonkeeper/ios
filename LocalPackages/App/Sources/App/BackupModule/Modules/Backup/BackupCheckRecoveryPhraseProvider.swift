import TKScreenKit
import TKLocalize
import KeeperCore

struct BackupCheckRecoveryPhraseProvider: TKCheckRecoveryPhraseProvider {
  
  var title: String {
    TKLocales.Backup.Check.Input.title
  }
  
  func caption(numberOne: Int, numberTwo: Int, numberThree: Int) -> String {
    TKLocales.Backup.Check.Input.caption(numberOne, numberTwo, numberThree)
  }
  
  var buttonTitle: String {
    TKLocales.Backup.Check.Input.Button.title
  }
  
  let phrase: [String]
  
  init(phrase: [String]) {
    self.phrase = phrase
  }
}
