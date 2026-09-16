import AppUI
import TKLocalize

struct OnboardingRecoveryPhraseDataProvider: TKRecoveryPhraseDataProvider {
    private enum ActionID {
        static let checkBackup = "checkBackup"
    }

    var didTapNext: (() -> Void)?

    var state: RecoveryPhraseScreenState {
        createState()
    }

    private let phrase: [String]

    init(phrase: [String]) {
        self.phrase = phrase
    }
}

private extension OnboardingRecoveryPhraseDataProvider {
    func createState() -> RecoveryPhraseScreenState {
        RecoveryPhraseScreenState(
            title: TKLocales.Backup.Check.title,
            caption: TKLocales.Backup.Check.caption,
            words: phrase.enumerated().map {
                RecoveryPhraseScreenState.Word(
                    index: $0.offset + 1,
                    value: $0.element
                )
            },
            actions: [
                RecoveryPhraseScreenState.Action(
                    id: ActionID.checkBackup,
                    title: TKLocales.Backup.Check.Button.title,
                    style: .primary
                ),
            ]
        )
    }
}

extension OnboardingRecoveryPhraseDataProvider {
    func didTapAction(id: RecoveryPhraseScreenState.Action.ID) {
        guard id == ActionID.checkBackup else { return }
        didTapNext?()
    }
}
