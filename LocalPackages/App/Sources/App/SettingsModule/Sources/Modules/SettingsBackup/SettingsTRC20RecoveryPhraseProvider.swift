import KeeperCore
import TKLocalize
import TKScreenKit
import TKUIKit
import UIKit

struct SettingsTRC20RecoveryPhraseProvider: TKRecoveryPhraseDataProvider {
    var didTapTRC20Button: (() -> Void)?

    var model: TKRecoveryPhraseView.Model {
        createModel()
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
    func createModel() -> TKRecoveryPhraseView.Model {
        let tronMnemonic = TonTron.tonMnemonicToTronMnemonic(tonMnemonic)

        let phraseListViewModel = TKRecoveryPhraseListView.Model(
            wordModels: tronMnemonic
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
            title: .plainString(TKLocales.Backup.Trc20.Show.Button.title),
            icon: .TKUIKit.Icons.Size16.copy
        )
        copyButtonConfiguration.action = {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            UIPasteboard.general.string = tronMnemonic.joined(separator: " ")
            ToastPresenter.showToast(configuration: .copied)
        }
        buttons.append(
            TKRecoveryPhraseView.Model.Button(
                configuration: copyButtonConfiguration,
                isFullWidth: false
            )
        )

        return TKRecoveryPhraseView.Model(
            titleDescriptionModel: TKTitleDescriptionView.Model(
                title: TKLocales.Backup.Trc20.Show.title,
                bottomDescription: TKLocales.Backup.Trc20.Show.caption
            ),
            bannerViewModel: TKRecoverPhraseBannerView.Model(
                text: TKLocales.Backup.Trc20.Show.banner
            ),
            phraseListViewModel: phraseListViewModel,
            buttons: buttons
        )
    }
}
