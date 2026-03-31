import KeeperCore
import TKLocalize
import TKScreenKit
import TKUIKit
import UIKit

struct BackupRecoveryPhraseDataProvider: TKRecoveryPhraseDataProvider {
    var didTapNext: (() -> Void)?

    var model: TKRecoveryPhraseView.Model {
        createModel()
    }

    private let phrase: [String]

    init(phrase: [String]) {
        self.phrase = phrase
    }
}

private extension BackupRecoveryPhraseDataProvider {
    func createModel() -> TKRecoveryPhraseView.Model {
        let phraseListViewModel = TKRecoveryPhraseListView.Model(
            wordModels: phrase
                .enumerated()
                .map { index, word in
                    TKRecoveryPhraseItemView.Model(index: index + 1, word: word)
                }
        )

        var checkBackupConfiguration = TKButton.Configuration.actionButtonConfiguration(
            category: .primary,
            size: .large
        )
        checkBackupConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(TKLocales.Backup.Check.Button.title)
        )
        checkBackupConfiguration.action = {
            self.didTapNext?()
        }

        return TKRecoveryPhraseView.Model(
            titleDescriptionModel: TKTitleDescriptionView.Model(
                title: TKLocales.Backup.Check.title,
                bottomDescription: TKLocales.Backup.Check.caption
            ),
            phraseListViewModel: phraseListViewModel,
            buttons: [
                TKRecoveryPhraseView.Model.Button(configuration: checkBackupConfiguration, isFullWidth: true),
            ]
        )
    }
}
