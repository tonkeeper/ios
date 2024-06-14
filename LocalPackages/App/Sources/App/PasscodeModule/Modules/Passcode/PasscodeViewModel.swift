import UIKit
import TKUIKit

protocol PasscodeModuleOutput: AnyObject {
  var biometryProvider: (() async -> TKKeyboardView.Biometry)? { get set }
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

  var biometryProvider: (() async -> TKKeyboardView.Biometry)?
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
    Task {
      let biometry = await biometryProvider?() ?? .none
      await MainActor.run {
        didUpdateBiometry?(biometry)
        didTapBiometryButton()
      }
    }
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
}
