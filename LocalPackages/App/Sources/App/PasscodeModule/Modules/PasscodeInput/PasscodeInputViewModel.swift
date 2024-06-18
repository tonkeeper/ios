import UIKit
import TKUIKit

enum PasscodeInputValidationResult {
  case success
  case failed
  case none
}

protocol PasscodeInputModuleOutput: AnyObject {
  var validateInput: ((String) async -> PasscodeInputValidationResult)? { get set }
  var didFinish: ((String) -> Void)? { get set }
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
  
  var validateInput: ((String) async -> PasscodeInputValidationResult)?
  var didFinish: ((String) -> Void)?
  var didFailed: (() -> Void)?
  
  // MARK: - PasscodeInputModuleInput
  
  func didTapDigit(_ digit: Int) {
    guard isInputEnable else { return }
    input += "\(digit)"
    didUpdateInput()
  }
  
  func didTapBackspace() {
    guard isInputEnable else { return }
    input = String(input.dropLast(1))
    didUpdateInput()
  }
  
  func didSetInput(_ input: String) {
    guard isInputEnable else { return }
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
  private var isInputEnable = true
  
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
      
      isInputEnable = false
      guard let validateInput else {
        isInputEnable = true
        return
      }
      Task {
        let result = await validateInput(input)
        let state: PasscodeInputView.State
        switch result {
        case .success:
          state = .success
        case .failed:
          state = .failed(inputCount)
        case .none:
          state = .input(inputCount)
        }
        
        await MainActor.run {
          didUpdateState?(state, { [weak self] in
            self?.isInputEnable = true
            switch result {
            case .success, .none:
              self?.didFinish?(input)
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
