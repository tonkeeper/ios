import Foundation
import TKScreenKit
import TonSwift

struct InputRecoveryPhraseValidator: TKInputRecoveryPhraseValidator {
  func validateWord(_ word: String) -> Bool {
    Mnemonic.words.contains(word)
  }
  
  func validatePhrase(_ phrase: [String]) -> Bool {
    Mnemonic.mnemonicValidate(mnemonicArray: phrase)
  }
}
