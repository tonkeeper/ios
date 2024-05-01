import UIKit
import TKUIKit
import TKScreenKit
import SignerCore

protocol ShowRecoveryPhraseViewModel: AnyObject {
  var didUpdateModel: ((TKRecoveryPhraseView.Model) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapCopyButton()
}

protocol ShowRecoveryPhraseModuleOutput: AnyObject {
  
}

final class ShowRecoveryPhraseViewModelImplementation: ShowRecoveryPhraseViewModel, ShowRecoveryPhraseModuleOutput {
  
  // MARK: - ShowRecoveryPhraseModuleOutput
  
  // MARK: - ShowRecoveryPhraseViewModel
  
  var didUpdateModel: ((TKRecoveryPhraseView.Model) -> Void)?
  
  func viewDidLoad() {
    
    let model = TKRecoveryPhraseView.Model(
      titleDescriptionModel: TKTitleDescriptionHeaderView.Model(
        title: "Recovery Phrase",
        bottomDescription: "Keep your seed phrase in secure location. Do not enter it into unknown apps."
      ),
      phraseListViewModel: TKRecoveryPhraseListView.Model(wordModels: recoveryPhraseController.getRecoveryPhrase().enumerated().map {
        TKRecoveryPhraseItemView.Model(
          index: $0.offset + 1,
          word: $0.element
        )
      })
    )
    didUpdateModel?(model)
  }
  
  func didTapCopyButton() {
    UIPasteboard.general.string = recoveryPhraseController.getRecoveryPhrase().joined(separator: "\n")
  }
  
  // MARK: - Dependencies
  
  private var recoveryPhraseController: RecoveryPhraseController
  
  // MARK: - Init
  
  init(recoveryPhraseController: RecoveryPhraseController) {
    self.recoveryPhraseController = recoveryPhraseController
  }
}
