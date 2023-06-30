//
//  PasscodeInputPasscodeInputPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/06/2023.
//

import Foundation
import WalletCore

enum PasscodeInputPresenterValidation {
  case success
  case filled
  case failed
}

protocol PasscodeInputPresenterConfigurator {
  var title: String { get }
  var didFinish: ((_ passcode: Passcode) -> Void)? { get set }
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
  private var successHandler: (() -> Void)?
  
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
    successHandler?()
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
    case 0..<Passcode.length:
      inputState = .input(count: input.count)
      validationState = .none
    case Passcode.length:
      let passcode = try! Passcode(value: input)
      successHandler = { [weak self] in
        self?.configurator.didFinish?(passcode)
      }
      viewInput?.didEnterPin()
      inputState = .input(count: input.count)
      switch configurator.validateInput(input) {
      case .filled:
        validationState = .none
        successHandler?()
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
