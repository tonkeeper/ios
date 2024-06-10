import UIKit
import TKUIKit
import TKScreenKit
import SignerCore
import SignerLocalize

struct RecoveryPhraseDataProvider: TKRecoveryPhraseDataProvider {
  
  var model: TKRecoveryPhraseView.Model {
    get async {
      await createModel()
    }
  }
  
  private let recoveryPhraseController: RecoveryPhraseController
  
  init(recoveryPhraseController: RecoveryPhraseController) {
    self.recoveryPhraseController = recoveryPhraseController
  }
}

private extension RecoveryPhraseDataProvider {
  func createModel() async -> TKRecoveryPhraseView.Model {
    let phraseListViewModel = await TKRecoveryPhraseListView.Model(
      wordModels: recoveryPhraseController.getRecoveryPhrase()
        .enumerated()
        .map { index, word in
          TKRecoveryPhraseItemView.Model(index: index + 1, word: word)
        }
    )
    
    return TKRecoveryPhraseView.Model(
      titleDescriptionModel: TKTitleDescriptionView.Model(
        title: SignerLocalize.Recovery.Phrase.title,
        bottomDescription: SignerLocalize.Recovery.Phrase.caption
      ),
      phraseListViewModel: phraseListViewModel,
      buttons: [
        TKRecoveryPhraseView.Model.Button(
          model: TKUIActionButton.Model(title: SignerLocalize.Actions.copy),
          category: .secondary,
          action: {
            Task {
              let recoveryPhrase = await recoveryPhraseController.getRecoveryPhrase().joined(separator: "\n")
              await MainActor.run {
                UIPasteboard.general.string = recoveryPhrase
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                ToastPresenter.showToast(configuration: .Signer.copied)
              }
            }
          }
        )
      ]
    )
  }
}
