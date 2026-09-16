import AppUI
import KeeperCore
import TKLocalize
import TKUIKit

struct SettingsTRC20RecoveryPhraseProvider: TKRecoveryPhraseDataProvider {
    private enum ActionID {
        static let copy = "copy"
    }

    var state: RecoveryPhraseScreenState {
        createState()
    }

    private let wallet: Wallet
    private let tonMnemonic: [String]

    init(
        wallet: Wallet,
        tonMnemonic: [String]
    ) {
        self.wallet = wallet
        self.tonMnemonic = tonMnemonic
    }
}

private extension SettingsTRC20RecoveryPhraseProvider {
    func createState() -> RecoveryPhraseScreenState {
        let tronMnemonic = TonTron.tonMnemonicToTronMnemonic(tonMnemonic)

        return RecoveryPhraseScreenState(
            title: TKLocales.Backup.Trc20.Show.title,
            caption: TKLocales.Backup.Trc20.Show.caption,
            banner: TKLocales.Backup.Trc20.Show.banner,
            words: tronMnemonic.enumerated().map {
                RecoveryPhraseScreenState.Word(
                    index: $0.offset + 1,
                    value: $0.element
                )
            },
            actions: [
                RecoveryPhraseScreenState.Action(
                    id: ActionID.copy,
                    title: TKLocales.Backup.Trc20.Show.Button.title,
                    icon: .TKUIKit.Icons.Size16.copy,
                    style: .secondary
                ),
            ]
        )
    }
}

extension SettingsTRC20RecoveryPhraseProvider {
    func didTapAction(id: RecoveryPhraseScreenState.Action.ID) {
        guard id == ActionID.copy else { return }
        let tronMnemonic = TonTron.tonMnemonicToTronMnemonic(tonMnemonic)
        Pasteboard.copySensitive(
            value: tronMnemonic.joined(separator: " ")
        )
    }
}
