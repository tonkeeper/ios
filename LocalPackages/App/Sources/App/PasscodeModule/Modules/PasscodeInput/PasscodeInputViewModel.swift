import UIKit
import TKUIKit

enum PasscodeInputValidationResult {
  case success
  case failed
  case none
}

protocol PasscodeInputModuleOutput: AnyObject {
  var didFinishInput: ((String) async -> PasscodeInputValidationResult)? { get set }
  var didEnterPasscode: ((String) -> Void)? { get set }
  var didFailed: (() -> Void)? { get set }
}

protocol PasscodeInputModuleInput: AnyObject {
  func didTapDigit(_ digit: Int)
  func didTapBackspace()
  func didSetInput(_ input: String)
}

protocol PasscodeInputViewModel: AnyObject {
  var didUpdateTitle: ((String?) -> Void)? { get set }
  var didUpdateState: ((PasscodeInputView.State, (() -> Void)?) -> Void)? { get set }
  
  func viewDidLoad()
  func viewDidDisappear()
}

final class PasscodeInputViewModelImplementation: PasscodeInputViewModel, PasscodeInputModuleInput, PasscodeInputModuleOutput {
  
  // MARK: - PasscodeInputModuleOutput
  
  var didFinishInput: ((String) async -> PasscodeInputValidationResult)?
  var didEnterPasscode: ((String) -> Void)?
  var didFailed: (() -> Void)?
  
  // MARK: - PasscodeInputModuleInput
  
  func didTapDigit(_ digit: Int) {
    input += "\(digit)"
    didUpdateInput()
  }
  
  func didTapBackspace() {
    input = String(input.dropLast(1))
    didUpdateInput()
  }
  
  func didSetInput(_ input: String) {
    self.input = input
    didUpdateInput()
  }

  // MARK: - PasscodeInputViewModel
  
  var didUpdateTitle: ((String?) -> Void)?
  var didUpdateState: ((PasscodeInputView.State, (() -> Void)?) -> Void)?

  func viewDidLoad() {
    input = ""
    didUpdateTitle?(title)
  }
  
  func viewDidDisappear() {
    input = ""
    didUpdateState?(.input(0), nil)
  }
  
  // MARK: - State
  
  private var input = ""
  
  // MARK: - Dependencies
  
  private let title: String
  
  init(title: String) {
    self.title = title
  }
}

private extension PasscodeInputViewModelImplementation {
  func didUpdateInput() {
    let input = input
    let inputCount = input.count
    let state: PasscodeInputView.State
    
    switch inputCount {
    case 0..<Int.passcodeLength:
      state = .input(inputCount)
      didUpdateState?(state, nil)
    case Int.passcodeLength:
      state = .input(inputCount)
      didUpdateState?(state, nil)
      
      Task {
        guard let validationResult = await didFinishInput?(input) else {
          return
        }
        let state: PasscodeInputView.State
        switch validationResult {
        case .success:
          state = .success
        case .failed:
          state = .failed(inputCount)
        case .none:
          state = .input(inputCount)
        }
        
        await MainActor.run {
          didUpdateState?(state, { [weak self] in
            switch validationResult {
            case .success, .none:
              self?.didEnterPasscode?(input)
            case .failed:
              self?.didFailed?()
            }
            self?.input = ""
          })
        }
      }
    default:
      break
    }
  }
}

private extension Int {
  static let passcodeLength = 4
}
