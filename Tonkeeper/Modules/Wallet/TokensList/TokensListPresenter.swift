//
//  TokensListTokensListPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 26/05/2023.
//

import Foundation

final class TokensListPresenter {
  
  private let sections: [TokensListSection]
  
  init(sections: [TokensListSection]) {
    self.sections = sections
  }
  
  // MARK: - Module
  
  weak var viewInput: TokensListViewInput?
  weak var output: TokensListModuleOutput?
}

// MARK: - TokensListPresenterIntput

extension TokensListPresenter: TokensListPresenterInput {
  func viewDidLoad() {
    viewInput?.presentSections(sections)
  }
}

// MARK: - TokensListModuleInput

extension TokensListPresenter: TokensListModuleInput {}

// MARK: - Private

private extension TokensListPresenter {}
