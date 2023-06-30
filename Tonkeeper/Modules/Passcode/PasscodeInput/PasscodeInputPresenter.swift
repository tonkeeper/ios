//
//  PasscodeInputPasscodeInputPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/06/2023.
//

import Foundation

enum PasscodeInputPresenterValidation {
  case success
  case filled
  case failed
}

protocol PasscodeInputPresenterConfigurator {
  var title: String { get }
  var didFinish: ((_ passcode: String) -> Void)? { get set }
  var didFailed: (() -> Void)? { get set }
  var isBiometryAvailable: Bool { get }
  func validateInput(_ input: String) -> PasscodeInputPresenterValidation
}

final class PasscodeInputPresenter {
  
  // MARK: - Module
  
  weak var viewInput: PasscodeInputViewInput?
  weak var output: PasscodeInputModuleOutput?
  
  // MARK: - Dependencies
  
  private let configurator: PasscodeInputPresenterConfigurator
  
  // MARK: - State
  
  private var input: String = ""
  
  init(configurator: PasscodeInputPresenterConfigurator) {
    self.configurator = configurator
  }
}

// MARK: - PasscodeInputPresenterIntput

extension PasscodeInputPresenter: PasscodeInputPresenterInput {
  func viewDidLoad() {
    updateTitle()
    updateBiometryAvailability()
  }
  
  func viewDidDisappear() {
    reset()
  }
  
  func didTapDigitButton(digit: Int) {
    input += "\(digit)"
    viewInput?.handleDigitInput(at: max(0, input.count - 1))
    updateInputState()
  }
  
  func didTapBiometryButton() {
    
  }
  
  func didTapBackspaceButton() {
    input = String(input.dropLast(1))
    updateInputState()
  }
  
  func didHandleInputFailed() {
    reset()
    configurator.didFailed?()
  }
  
  func didHandleInputSuccess() {
    configurator.didFinish?(input)
  }
}

// MARK: - PasscodeInputModuleInput

extension PasscodeInputPresenter: PasscodeInputModuleInput {}

// MARK: - Private

private extension PasscodeInputPresenter {
  func updateTitle() {
    viewInput?.updateTitle(configurator.title)
  }
  
  func updateBiometryAvailability() {
    viewInput?.updateBiometryAvailability(configurator.isBiometryAvailable)
  }
  
  func updateInputState() {
    var inputState: PasscodeDotRowView.InputState = .input(count: 0)
    var validationState: PasscodeDotRowView.ValidationState = .none
    switch input.count {
    case 0..<Int.pinLength:
      inputState = .input(count: input.count)
      validationState = .none
    case Int.pinLength:
      viewInput?.didEnterPin()
      inputState = .input(count: input.count)
      switch configurator.validateInput(input) {
      case .filled:
        validationState = .none
        configurator.didFinish?(input)
      case .success:
        validationState = .success
        viewInput?.handlePinInputSuccess()
      case .failed:
        validationState = .failed
        viewInput?.handlePinInputFailed()
      }
    default:
      break
    }
    
    viewInput?.updateDotRow(
      with: inputState,
      validationState: validationState
    )
  }
  
  func reset() {
    input = ""
    updateInputState()
    viewInput?.didResetPin()
  }
}

private extension Int {
  static let pinLength = 4
}
