import Foundation
import TKUIKit
import SignerLocalize

protocol PasswordInputViewModel: AnyObject {
  var didUpdateTitle: ((TKTitleDescriptionView.Model) -> Void)? { get set }
  var didUpdateTextFieldCaption: ((String?) -> Void)? { get set }
  var didUpdateContinueButton: ((TKButton.Configuration) -> Void)? { get set }
  var didUpdateIsContinueButtonEnabled: ((Bool) -> Void)? { get set }
  var didUpdateIsValidInput: ((Bool) -> Void)? { get set }
  var didMakeInputActive: (() -> Void)? { get set }
  
  var input: String { get }
  
  func viewDidLoad()
  func viewWillAppear(isMovingToParent: Bool)
  func viewDidAppear()
  func didUpdateInput(_ input: String)
}

protocol PasswordInputModuleOutput: AnyObject {
  var didEnterPassword: ((String) -> Void)? { get set }
}

final class PasswordInputViewModelImplementation: PasswordInputViewModel, PasswordInputModuleOutput {
  var didUpdateTitle: ((TKTitleDescriptionView.Model) -> Void)?
  var didUpdateTextFieldCaption: ((String?) -> Void)?
  var didUpdateContinueButton: ((TKButton.Configuration) -> Void)?
  var didUpdateIsContinueButtonEnabled: ((Bool) -> Void)?
  var didUpdateIsValidInput: ((Bool) -> Void)?
  var didMakeInputActive: (() -> Void)?
  
  var didEnterPassword: ((String) -> Void)?
  
  private let configurator: PasswordInputViewModelConfigurator
  
  var input = ""
  
  init(configurator: PasswordInputViewModelConfigurator) {
    self.configurator = configurator
  }
  
  func viewDidLoad() {
    let titleDescriptionModel: TKTitleDescriptionView.Model = .init(
      title: configurator.title
    )
    didUpdateTitle?(titleDescriptionModel)
    didUpdateTextFieldCaption?(configurator.textFieldCaption)
    
    var continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    continueButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(SignerLocalize.Actions.continue_action))
    continueButtonConfiguration.action = { [weak self] in
      guard let self = self else { return }
      let isValid = self.configurator.validateInput(self.input.hashed)
      guard isValid else {
        self.didUpdateIsValidInput?(isValid)
        return
      }
      self.didEnterPassword?(input.hashed)
    }
    didUpdateContinueButton?(continueButtonConfiguration)
    
    didUpdateIsContinueButtonEnabled?(false)
  }
  
  func viewWillAppear(isMovingToParent: Bool) {
    if configurator.showKeyboardWhileAppear || !isMovingToParent {
      didMakeInputActive?()
    }
  }
  
  func viewDidAppear() {
    if !configurator.showKeyboardWhileAppear {
      didMakeInputActive?()
    }
  }
  
  func didUpdateInput(_ input: String) {
    self.input = input
    didUpdateIsContinueButtonEnabled?(configurator.isContinueEnable(input))
    didUpdateIsValidInput?(true)
  }
}
