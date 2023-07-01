//
//  PasscodeInputPasscodeInputProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/06/2023.
//

import Foundation

protocol PasscodeInputModuleOutput: AnyObject {}

protocol PasscodeInputModuleInput: AnyObject {}

protocol PasscodeInputPresenterInput {
  func viewDidLoad()
  func viewDidDisappear()
  func didTapDigitButton(digit: Int)
  func didTapBiometryButton()
  func didTapBackspaceButton()
  func didHandleInputFailed()
  func didHandleInputSuccess()
}

protocol PasscodeInputViewInput: AnyObject {
  func updateDotRow(with inputState: PasscodeDotRowView.InputState,
                    validationState: PasscodeDotRowView.ValidationState)
  func updateTitle(_ title: String)
  func updateBiometryAvailability(_ isAvailable: Bool)
  func handlePinInputFailed()
  func handlePinInputSuccess()
  func handleDigitInput(at index: Int)
  func didEnterPin()
  func didResetPin()
}
