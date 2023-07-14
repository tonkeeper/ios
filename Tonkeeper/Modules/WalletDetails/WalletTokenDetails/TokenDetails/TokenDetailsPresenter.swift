//
//  TokenDetailsTokenDetailsPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 13/07/2023.
//

import Foundation

final class TokenDetailsPresenter {
  
  // MARK: - Module
  
  weak var viewInput: TokenDetailsViewInput?
  weak var output: TokenDetailsModuleOutput?
}

// MARK: - TokenDetailsPresenterIntput

extension TokenDetailsPresenter: TokenDetailsPresenterInput {
  func viewDidLoad() {}
}

// MARK: - TokenDetailsModuleInput

extension TokenDetailsPresenter: TokenDetailsModuleInput {}

// MARK: - Private

private extension TokenDetailsPresenter {}
