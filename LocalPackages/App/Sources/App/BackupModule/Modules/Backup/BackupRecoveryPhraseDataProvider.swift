import UIKit
import TKUIKit
import TKScreenKit
import KeeperCore

struct BackupRecoveryPhraseDataProvider: TKRecoveryPhraseDataProvider {
  
  public var didTapNext: (() -> Void)?
  
  var model: TKRecoveryPhraseView.Model {
    createModel()
  }
  
  private let recoveryPhraseController: RecoveryPhraseController
  
  init(recoveryPhraseController: RecoveryPhraseController) {
    self.recoveryPhraseController = recoveryPhraseController
  }
}

private extension BackupRecoveryPhraseDataProvider {
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
          model: TKUIActionButton.Model(title: "Check Backup"),
          category: .primary,
          action: {
            self.didTapNext?()
          }
        )
      ]
    )
  }
}
