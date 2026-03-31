import TKLocalize
import TKScreenKit
import TKUIKit

struct OnboardingRecoveryPhraseDataProvider: TKRecoveryPhraseDataProvider {
    var didTapNext: (() -> Void)?

    var model: TKRecoveryPhraseView.Model {
        createModel()
    }

    private let phrase: [String]

    init(phrase: [String]) {
        self.phrase = phrase
    }
}

private extension OnboardingRecoveryPhraseDataProvider {
    func createModel() -> TKRecoveryPhraseView.Model {
        let phraseListViewModel = TKRecoveryPhraseListView.Model(
            wordModels: phrase.enumerated().map { index, word in
                TKRecoveryPhraseItemView.Model(index: index + 1, word: word)
            }
        )

        var continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
            category: .primary,
            size: .large
        )
        continueButtonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(TKLocales.Actions.continueAction)
        )
        continueButtonConfiguration.action = {
            self.didTapNext?()
        }

        return TKRecoveryPhraseView.Model(
            titleDescriptionModel: TKTitleDescriptionView.Model(
                title: TKLocales.Backup.Check.title,
                bottomDescription: TKLocales.Backup.Check.caption
            ),
            phraseListViewModel: phraseListViewModel,
            buttons: [
                TKRecoveryPhraseView.Model.Button(
                    configuration: continueButtonConfiguration,
                    isFullWidth: true
                ),
            ]
        )
    }
}
