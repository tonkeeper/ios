import Foundation
import TKUIKit

protocol EditWalletNameViewModel: AnyObject {
  var didUpdateTitleDescription: ((TKTitleDescriptionHeaderView.Model) -> Void)? { get set }
  var didUpdateWalletNameTextFieldValue: ((String?) -> Void)? { get set }
  var didUpdateWalletNameTextFieldPlaceholder: ((String) -> Void)? { get set }
  var didUpdateContinueButton: ((TKButtonControl<ButtonTitleContentView>.Model) -> Void)? { get set }
  var didUpdateIsContinueButtonEnabled: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
  func didUpdateInput(_ input: String)
}

protocol EditWalletNameModuleOutput: AnyObject {
  var didEnterWalletName: ((String) -> Void)? { get set }
}

final class EditWalletNameViewModelImplementation: EditWalletNameViewModel, EditWalletNameModuleOutput {
  var didUpdateTitleDescription: ((TKTitleDescriptionHeaderView.Model) -> Void)?
  var didUpdateWalletNameTextFieldPlaceholder: ((String) -> Void)?
  var didUpdateWalletNameTextFieldValue: ((String?) -> Void)?
  var didUpdateContinueButton: ((TKButtonControl<ButtonTitleContentView>.Model) -> Void)?
  var didUpdateIsContinueButtonEnabled: ((Bool) -> Void)?
  
  var didEnterWalletName: ((String) -> Void)?
  
  private let configurator: EditWalletNameViewModelConfigurator
  private var defaultName: String?
  
  private var input = ""
  
  init(configurator: EditWalletNameViewModelConfigurator, defaultName: String?) {
    self.configurator = configurator
    self.defaultName = defaultName
  }
  
  func viewDidLoad() {
    let titleDescriptionModel: TKTitleDescriptionHeaderView.Model = .init(
      title: "Name your Key",
      bottomDescription: "It will simplify the search for the necessary key in the list of keys."
    )
    didUpdateTitleDescription?(titleDescriptionModel)
    
    didUpdateWalletNameTextFieldPlaceholder?("Name")
    didUpdateWalletNameTextFieldValue?(defaultName)
    
    let continueButtonModel = TKButtonControl<ButtonTitleContentView>.Model(
      contentModel: .init(title: configurator.continueButtonTitle)
    ) { [weak self] in
      guard let self = self else { return }
      Task {
        await self.configurator.handleContinueButtonTapped()
        await MainActor.run {
          self.didEnterWalletName?(self.input)
        }
      }
    }
    didUpdateContinueButton?(continueButtonModel)
    
    didUpdateIsContinueButtonEnabled?(false)
  }
  
  func didUpdateInput(_ input: String) {
    self.input = input
    didUpdateIsContinueButtonEnabled?(isContinueEnable(input: input))
  }
}

private extension EditWalletNameViewModelImplementation {
  func isContinueEnable(input: String) -> Bool {
    !input.isEmpty
  }
}
