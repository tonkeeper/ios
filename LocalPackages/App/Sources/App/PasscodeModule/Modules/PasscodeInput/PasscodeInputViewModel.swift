import UIKit
import TKUIKit

public protocol PasscodeInputModuleOutput: AnyObject {
  var didInputPasscode: ((String) -> Void)? { get set }
  var didFailed: (() -> Void)? { get set }
}

protocol PasscodeInputViewModel: AnyObject {
  var didUpdateModel: ((PasscodeInputView.Model) -> Void)? { get set }
  var didUpdatePasscodeInputState: ((PasscodeDotRowView.InputState) -> Void)? { get set }
  var didUpdatePasscodeValidationState: ((PasscodeDotRowView.ValidationState, (() -> Void)?) -> Void)? { get set }
  
  func viewDidLoad()
  func viewDidDisappear()
  func didTapDigit(_ digit: Int)
  func didTapBackspace()
  func didTapBiometry()
}

public enum PasscodeInputValidatorResult {
  case none
  case success
  case failed
}

public protocol PasscodeInputValidator {
  func validatePasscodeInput(_ input: String) -> PasscodeInputValidatorResult
}

public enum PasscodeInputBiometryProviderState {
  case touchId
  case faceId
  case none
}

public protocol PasscodeInputBiometryProvider {
  var didSuccessBiometry: (() -> Void)? { get set }
  var didFailedBiometry: (() -> Void)? { get set }
  
  func checkBiometryStatus() -> PasscodeInputBiometryProviderState
  func evaluateBiometry()
}

final class PasscodeInputViewModelImplementation: PasscodeInputViewModel, PasscodeInputModuleOutput {
  
  // MARK: - PasscodeInputModuleOutput
  
  var didInputPasscode: ((String) -> Void)?
  var didFailed: (() -> Void)?
  
  // MARK: - PasscodeInputViewModel
  
  var didUpdateModel: ((PasscodeInputView.Model) -> Void)?
  var didUpdatePasscodeInputState: ((PasscodeDotRowView.InputState) -> Void)?
  var didUpdatePasscodeValidationState: ((PasscodeDotRowView.ValidationState, (() -> Void)?) -> Void)?
  
  func viewDidLoad() {
    didUpdateModel?(createModel())
    switch biometryProvider.checkBiometryStatus() {
    case .faceId, .touchId: biometryProvider.evaluateBiometry()
    case .none: break
    }
  }
  
  func viewDidDisappear() {
    reset()
  }
  
  func didTapDigit(_ digit: Int) {
    input += "\(digit)"
  }
  
  func didTapBackspace() {
    input = String(input.dropLast(1))
  }
  
  func didTapBiometry() {
    biometryProvider.evaluateBiometry()
  }
  
  // MARK: - State
  
  private var input = "" {
    didSet {
      handleInputUpdate()
    }
  }
  
  // MARK: - Configuration
  
  let title: String
  let validator: PasscodeInputValidator
  let biometryProvider: PasscodeInputBiometryProvider
  
  // MARK: - Init
  
  init(title: String,
       validator: PasscodeInputValidator,
       biometryProvider: PasscodeInputBiometryProvider) {
    self.title = title
    self.validator = validator
    self.biometryProvider = biometryProvider
  }
}

private extension PasscodeInputViewModelImplementation {
  func createModel() -> PasscodeInputView.Model {
    
    let biometry: TKKeyboardView.Configuration.Biometry?
    switch biometryProvider.checkBiometryStatus() {
    case .touchId:
      biometry = .touchId
    case .faceId:
      biometry = .faceId
    case .none:
      biometry = nil
    }
    
    return PasscodeInputView.Model(
      title: title,
      keyboardConfiguration: .passcodeConfiguration(biometry: biometry)
    )
  }
  
  func handleInputUpdate() {
    switch input.count {
    case 0..<Int.passcodeLength:
      didUpdatePasscodeInputState?(.input(count: input.count))
      didUpdatePasscodeValidationState?(.none, nil)
    case Int.passcodeLength:
      didUpdatePasscodeInputState?(.input(count: input.count))
      let validationResult = validator.validatePasscodeInput(input)
      switch validationResult {
      case .none:
        didUpdatePasscodeValidationState?(.none, nil)
        didInputPasscode?(input)
      case .success:
        didUpdatePasscodeValidationState?(.success, { [weak self, input] in
          self?.didInputPasscode?(input)
        })
      case .failed:
        didUpdatePasscodeValidationState?(.failed, { [weak self] in
          self?.didFailed?()
          self?.reset()
        })
      }
      
    default:
      break
    }
  }
  
  func reset() {
    input = ""
  }
}

private extension Int {
  static let passcodeLength = 4
}
