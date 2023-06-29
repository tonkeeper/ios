//
//  PasscodeInputPasscodeInputPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/06/2023.
//

import Foundation

final class PasscodeInputPresenter {
  
  // MARK: - Module
  
  weak var viewInput: PasscodeInputViewInput?
  weak var output: PasscodeInputModuleOutput?
}

// MARK: - PasscodeInputPresenterIntput

extension PasscodeInputPresenter: PasscodeInputPresenterInput {
  func viewDidLoad() {}
}

// MARK: - PasscodeInputModuleInput

extension PasscodeInputPresenter: PasscodeInputModuleInput {}

// MARK: - Private

private extension PasscodeInputPresenter {}
