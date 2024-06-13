import UIKit
import TKUIKit

protocol PasscodeModuleOutput: AnyObject {
  var didTapDigit: ((Int) -> Void)? { get set }
  var didTapBackspace: (() -> Void)? { get set }
  var didTapBiometry: (() -> Void)? { get set }
}

protocol PasscodeModuleInput: AnyObject {
  func disableInput()
  func enableInput()
}

protocol PasscodeViewModel: AnyObject {
  var didUpdateBiometry: ((TKKeyboardView.Biometry) -> Void)? { get set }
  var didEnableInput: (() -> Void)? { get set }
  var didDisableInput: (() -> Void)? { get set }
  
  func viewDidLoad()
  func didTapDigitButton(_ digit: Int)
  func didTapBackspaceButton()
  func didTapBiometryButton()
}

final class PasscodeViewModelImplementation: PasscodeViewModel, PasscodeModuleOutput, PasscodeModuleInput {
  
  // MARK: - PasscodeModuleOutput
  
  var didTapDigit: ((Int) -> Void)?
  var didTapBackspace: (() -> Void)?
  var didTapBiometry: (() -> Void)?
  
  // MARK: - PasscodeModuleInput
  
  func enableInput() {
    didEnableInput?()
  }
  
  func disableInput() {
    didDisableInput?()
  }
  
  // MARK: - PasscodeViewModel
  
  var didUpdateBiometry: ((TKKeyboardView.Biometry) -> Void)?
  var didEnableInput: (() -> Void)?
  var didDisableInput: (() -> Void)?
  
  func viewDidLoad() {
    
  }
  
  func didTapDigitButton(_ digit: Int) {
    didTapDigit?(digit)
  }
  
  func didTapBackspaceButton() {
    didTapBackspace?()
  }
  
  func didTapBiometryButton() {
    didTapBiometry?()
  }
  
  // MARK: - State
  
  private var isBiometryEnable = false
  
  // MARK: - Dependencies
  
  private let isBiometryTurnedOn: Bool
  
  init(isBiometryTurnedOn: Bool) {
    self.isBiometryTurnedOn = isBiometryTurnedOn
  }
  
  private func checkIfBiometryEnable() async -> Bool {
    return false
  }
}
