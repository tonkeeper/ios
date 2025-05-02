import UIKit
import TKUIKit
import TKScreenKit
import TKLocalize
import KeeperCore

struct BackupRecoveryPhraseDataProvider: TKRecoveryPhraseDataProvider {
  
  public var didTapNext: (() -> Void)?
  
  var model: TKRecoveryPhraseView.Model {
    createModel()
  }
  
  private let wallet: Wallet
  private let phrase: [String]
  
  init(wallet: Wallet,
       phrase: [String]) {
    self.wallet = wallet
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
    
    var buttons = [TKButton.Configuration]()
    
    var copyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .secondary,
      size: .medium
    )
    copyButtonConfiguration.content = TKButton.Configuration.Content(
      title: .plainString(TKLocales.Actions.copy),
      icon: .TKUIKit.Icons.Size16.copy
    )
    copyButtonConfiguration.action = { [phrase] in
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
      UIPasteboard.general.string = phrase.joined(separator: " ")
      ToastPresenter.showToast(configuration: .copied)
    }
    buttons.append(copyButtonConfiguration)
    
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
