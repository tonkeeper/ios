import AppUI
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

final class SettingsRecoveryPhraseProvider: TKRecoveryPhraseDataProvider {
    private enum ActionID {
        static let copy = "copy"
        static let showTRC20 = "showTRC20"
    }

    var didTapTRC20Button: (() -> Void)?

    var state: RecoveryPhraseScreenState {
        createState()
    }

    private let wallet: Wallet
    private let phrase: [String]
    private let shouldShowTron: Bool

    init(
        wallet: Wallet,
        phrase: [String],
        shouldShowTron: Bool
    ) {
        self.wallet = wallet
        self.phrase = phrase
        self.shouldShowTron = shouldShowTron
    }
}

private extension SettingsRecoveryPhraseProvider {
    func createState() -> RecoveryPhraseScreenState {
        var actions = [
            RecoveryPhraseScreenState.Action(
                id: ActionID.copy,
                title: TKLocales.Backup.Show.Button.title,
                icon: .TKUIKit.Icons.Size16.copy,
                style: .secondary
            ),
        ]

        if shouldShowTron, wallet.tron != nil {
            actions.append(
                RecoveryPhraseScreenState.Action(
                    id: ActionID.showTRC20,
                    title: TKLocales.Backup.Show.Button.trc20,
                    icon: .TKUIKit.Icons.Size16.share,
                    style: .secondary
                )
            )
        }

        return RecoveryPhraseScreenState(
            title: TKLocales.Backup.Show.title,
            caption: TKLocales.Backup.Show.caption,
            words: phrase.enumerated().map {
                RecoveryPhraseScreenState.Word(
                    index: $0.offset + 1,
                    value: $0.element
                )
            },
            actions: actions
        )
    }
}

extension SettingsRecoveryPhraseProvider {
    func didTapAction(id: RecoveryPhraseScreenState.Action.ID) {
        switch id {
        case ActionID.copy:
            Pasteboard.copySensitive(value: phrase.joined(separator: " "))
        case ActionID.showTRC20:
            didTapTRC20Button?()
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        default:
            break
        }
    }
}
