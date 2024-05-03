import Foundation
import TKUIKit

protocol EditWalletNameViewModel: AnyObject {
  var didUpdateTitleDescription: ((TKTitleDescriptionView.Model) -> Void)? { get set }
  var didUpdateWalletNameTextFieldValue: ((String?) -> Void)? { get set }
  var didUpdateWalletNameTextFieldPlaceholder: ((String) -> Void)? { get set }
  var didUpdateContinueButton: ((TKButton.Configuration) -> Void)? { get set }
  var didUpdateIsContinueButtonEnabled: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
  func didUpdateInput(_ input: String)
}

protocol EditWalletNameModuleOutput: AnyObject {
  var didEnterWalletName: ((String) -> Void)? { get set }
}

final class EditWalletNameViewModelImplementation: EditWalletNameViewModel, EditWalletNameModuleOutput {
  var didUpdateTitleDescription: ((TKTitleDescriptionView.Model) -> Void)?
  var didUpdateWalletNameTextFieldPlaceholder: ((String) -> Void)?
  var didUpdateWalletNameTextFieldValue: ((String?) -> Void)?
  var didUpdateContinueButton: ((TKButton.Configuration) -> Void)?
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
    let titleDescriptionModel: TKTitleDescriptionView.Model = .init(
      title: "Name your Key",
      bottomDescription: "It will simplify the search for the necessary key in the list of keys."
    )
    didUpdateTitleDescription?(titleDescriptionModel)
    
    didUpdateWalletNameTextFieldPlaceholder?("Name")
    didUpdateWalletNameTextFieldValue?(defaultName)
    
    var continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    continueButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(configurator.continueButtonTitle))
    continueButtonConfiguration.action = { [weak self] in
      guard let self = self else { return }
      Task {
        await self.configurator.handleContinueButtonTapped()
        await MainActor.run {
          self.didEnterWalletName?(self.input)
        }
      }
    }
    didUpdateContinueButton?(continueButtonConfiguration)

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
