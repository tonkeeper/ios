import CoreComponents
import Foundation
import TKScreenKit
import TonSwift

struct AddWalletInputRecoveryPhraseValidator: TKInputRecoveryPhraseValidator {
    func validateWord(_ word: String) -> Bool {
        Mnemonic.words.contains(word)
    }

    func validatePhrase(_ phrase: [String]) -> RecoveryPhraseValidationResult {
        if Mnemonic.mnemonicValidate(mnemonicArray: phrase) {
            return .ton
        }
        if Mnemonic.isMultiAccountSeed(mnemonicArray: phrase) {
            return .multiaccount
        }
        if MnemonicLegacy.isValidBip39Mnemonic(mnemonicArray: phrase) {
            return .ton
        }
        return .invalid
    }
}
