import UIKit
import TKUIKit

public protocol PasscodeModuleOutput: AnyObject {
  var didTapDigit: ((Int) -> Void)? { get set }
  var didTapBackspace: (() -> Void)? { get set }
  var didTapBiometry: (() -> Void)? { get set }
  var didReset: (() -> Void)? { get set }
}

protocol PasscodeViewModel: AnyObject {
  var didUpdateModel: ((PasscodeView.Model) -> Void)? { get set }
  
  func viewDidLoad()
  func viewDidDisappear()
  func didTapDigitButton(_ digit: Int)
  func didTapBackspaceButton()
  func didTapBiometryButton()
}

final class PasscodeViewModelImplementation: PasscodeViewModel, PasscodeModuleOutput {
  
  // MARK: - PasscodeModuleOutput
  
  var didTapDigit: ((Int) -> Void)?
  var didTapBackspace: (() -> Void)?
  var didTapBiometry: (() -> Void)?
  var didReset: (() -> Void)?
  
  // MARK: - PasscodeViewModel
  
  var didUpdateModel: ((PasscodeView.Model) -> Void)?
  
  func viewDidLoad() {}
  
  func viewDidDisappear() {
    didReset?()
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
  
  private var input = "" {
    didSet {
      handleInputUpdate()
    }
  }
  
  let biometryProvider: PasscodeInputBiometryProvider
  
  // MARK: - Init
  
  init(biometryProvider: PasscodeInputBiometryProvider) {
    self.biometryProvider = biometryProvider
  }
}

private extension PasscodeViewModelImplementation {
  func createModel() -> PasscodeView.Model {
    
    let biometry: TKKeyboardView.Configuration.Biometry?
    switch biometryProvider.checkBiometryStatus() {
    case .touchId:
      biometry = .touchId
    case .faceId:
      biometry = .faceId
    case .none:
      biometry = nil
    }
    
    return PasscodeView.Model(
      keyboardConfiguration: .passcodeConfiguration(biometry: biometry)
    )
  }
  
  func handleInputUpdate() {}
}

private extension Int {
  static let passcodeLength = 4
}
