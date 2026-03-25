import KeeperCore
import TKLocalize
import TKScreenKit
import TKUIKit
import UIKit

final class SettingsRecoveryPhraseProvider: TKRecoveryPhraseDataProvider {
    var didTapTRC20Button: (() -> Void)?

    var model: TKRecoveryPhraseView.Model {
        createModel()
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
    func createModel() -> TKRecoveryPhraseView.Model {
        let phraseListViewModel = TKRecoveryPhraseListView.Model(
            wordModels: phrase
                .enumerated()
                .map { index, word in
                    TKRecoveryPhraseItemView.Model(index: index + 1, word: word)
                }
        )

        var buttons = [TKRecoveryPhraseView.Model.Button]()

        var copyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
            category: .secondary,
            size: .medium
        )
        copyButtonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(TKLocales.Backup.Show.Button.title),
            icon: .TKUIKit.Icons.Size16.copy
        )
        copyButtonConfiguration.action = { [phrase] in
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            UIPasteboard.general.string = phrase.joined(separator: " ")
            ToastPresenter.showToast(configuration: .copied)
        }
        buttons.append(
            TKRecoveryPhraseView.Model.Button(
                configuration: copyButtonConfiguration,
                isFullWidth: false
            )
        )

        if shouldShowTron, wallet.isTronTurnOn {
            var trc20ButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
                category: .secondary,
                size: .medium
            )
            trc20ButtonConfiguration.content = TKButton.Configuration.Content(
                title: .plainString(TKLocales.Backup.Show.Button.trc20),
                icon: .TKUIKit.Icons.Size16.share
            )
            trc20ButtonConfiguration.action = {
                self.didTapTRC20Button?()
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
            buttons.append(
                TKRecoveryPhraseView.Model.Button(
                    configuration: trc20ButtonConfiguration,
                    isFullWidth: false
                )
            )
        }

        return TKRecoveryPhraseView.Model(
            titleDescriptionModel: TKTitleDescriptionView.Model(
                title: TKLocales.Backup.Show.title,
                bottomDescription: TKLocales.Backup.Show.caption
            ),
            phraseListViewModel: phraseListViewModel,
            buttons: buttons
        )
    }
}
