import UIKit
import TKUIKit
import TKScreenKit
import TKLocalize
import KeeperCore

struct SettingsRecoveryPhraseProvider: TKRecoveryPhraseDataProvider {
  
  var model: TKRecoveryPhraseView.Model {
    createModel()
  }
  
  private let phrase: [String]
  
  init(phrase: [String]) {
    self.phrase = phrase
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
    
    return TKRecoveryPhraseView.Model(
      titleDescriptionModel: TKTitleDescriptionView.Model(
        title: TKLocales.Backup.Show.title,
        bottomDescription: TKLocales.Backup.Show.caption
      ),
      phraseListViewModel: phraseListViewModel,
      buttons: [
        TKRecoveryPhraseView.Model.Button(
          model: TKUIActionButton.Model(title: TKLocales.Backup.Show.Button.title),
          category: .secondary,
          action: {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            UIPasteboard.general.string = phrase.joined(separator: "\n")
            ToastPresenter.showToast(configuration: .copied)
          }
        )
      ]
    )
  }
}
