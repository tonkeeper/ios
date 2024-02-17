import UIKit
import TKUIKit
import TKScreenKit
import KeeperCore

struct SettingsRecoveryPhraseProvider: TKRecoveryPhraseDataProvider {
  
  var model: TKRecoveryPhraseView.Model {
    createModel()
  }
  
  private let recoveryPhraseController: RecoveryPhraseController
  
  init(recoveryPhraseController: RecoveryPhraseController) {
    self.recoveryPhraseController = recoveryPhraseController
  }
}

private extension SettingsRecoveryPhraseProvider {
  func createModel() -> TKRecoveryPhraseView.Model {
    let phraseListViewModel = TKRecoveryPhraseListView.Model(
      wordModels: recoveryPhraseController.getRecoveryPhrase()
        .enumerated()
        .map { index, word in
          TKRecoveryPhraseItemView.Model(index: index + 1, word: word)
        }
    )
    
    return TKRecoveryPhraseView.Model(
      titleDescriptionModel: TKTitleDescriptionView.Model(
        title: "Recovery Phrase",
        bottomDescription: "Write down these words with their numbers and store them in a safe place."
      ),
      phraseListViewModel: phraseListViewModel,
      buttons: [
        TKRecoveryPhraseView.Model.Button(
          model: TKUIActionButton.Model(title: "Copy"),
          category: .secondary,
          action: {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            UIPasteboard.general.string = recoveryPhraseController.getRecoveryPhrase().joined(separator: "\n")
            ToastPresenter.showToast(configuration: .copied)
          }
        )
      ]
    )
  }
}
