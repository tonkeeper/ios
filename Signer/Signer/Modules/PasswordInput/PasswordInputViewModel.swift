import Foundation
import TKUIKit

protocol PasswordInputViewModel: AnyObject {
  var didUpdateTitle: ((TKTitleDescriptionHeaderView.Model) -> Void)? { get set }
  var didUpdateContinueButton: ((TKButtonControl<ButtonTitleContentView>.Model) -> Void)? { get set }
  var didUpdateIsContinueButtonEnabled: ((Bool) -> Void)? { get set }
  var didUpdateIsValidInput: ((Bool) -> Void)? { get set }
  var didMakeInputActive: (() -> Void)? { get set }
  
  func viewDidLoad()
  func viewWillAppear(isMovingToParent: Bool)
  func viewDidAppear()
  func didUpdateInput(_ input: String)
}

protocol PasswordInputModuleOutput: AnyObject {
  var didEnterPassword: ((String) -> Void)? { get set }
}

final class PasswordInputViewModelImplementation: PasswordInputViewModel, PasswordInputModuleOutput {
  var didUpdateTitle: ((TKTitleDescriptionHeaderView.Model) -> Void)?
  var didUpdateContinueButton: ((TKButtonControl<ButtonTitleContentView>.Model) -> Void)?
  var didUpdateIsContinueButtonEnabled: ((Bool) -> Void)?
  var didUpdateIsValidInput: ((Bool) -> Void)?
  var didMakeInputActive: (() -> Void)?
  
  var didEnterPassword: ((String) -> Void)?
  
  private let configurator: PasswordInputViewModelConfigurator
  
  private var input = ""
  
  init(configurator: PasswordInputViewModelConfigurator) {
    self.configurator = configurator
  }
  
  func viewDidLoad() {
    let titleDescriptionModel: TKTitleDescriptionHeaderView.Model = .init(
      title: configurator.title
    )
    didUpdateTitle?(titleDescriptionModel)
    
    let continueButtonModel = TKButtonControl<ButtonTitleContentView>.Model(
      contentModel: .init(title: "Continue")
    ) { [weak self] in
      guard let self = self else { return }
      let isValid = self.configurator.validateInput(self.input)
      guard isValid else {
        self.didUpdateIsValidInput?(isValid)
        return
      }
      self.didEnterPassword?(input)
    }
    didUpdateContinueButton?(continueButtonModel)
    
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
