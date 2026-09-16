import KeeperCore
import TKLocalize
import TonSwift

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

    var validWords: [String] {
        Mnemonic.words
    }

    var errorCaption: String {
        TKLocales.Backup.Check.Input.error
    }

    let phrase: [String]
}
