import TKLocalize
import TonSwift

struct OnboardingCheckRecoveryPhraseProvider: TKCheckRecoveryPhraseProvider {
    let phrase: [String]

    var title: String {
        TKLocales.Backup.Check.Input.title
    }

    func caption(numberOne: Int, numberTwo: Int, numberThree: Int) -> String {
        TKLocales.Backup.Check.Input.caption(numberOne, numberTwo, numberThree)
    }

    var buttonTitle: String {
        TKLocales.Actions.continueAction
    }

    var validWords: [String] {
        Mnemonic.words
    }

    var errorCaption: String {
        TKLocales.Backup.Check.Input.error
    }
}
