//
//  EnterMnemonicEnterMnemonicPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import Foundation

final class EnterMnemonicPresenter {
  
  // MARK: - Module
  
  weak var viewInput: EnterMnemonicViewInput?
  weak var output: EnterMnemonicModuleOutput?
}

// MARK: - EnterMnemonicPresenterIntput

extension EnterMnemonicPresenter: EnterMnemonicPresenterInput {
  func viewDidLoad() {}
}

// MARK: - EnterMnemonicModuleInput

extension EnterMnemonicPresenter: EnterMnemonicModuleInput {}

// MARK: - Private

private extension EnterMnemonicPresenter {}
