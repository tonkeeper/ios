//
//  TokensListTokensListPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 26/05/2023.
//

import Foundation

final class TokensListPresenter {
  
  // MARK: - Module
  
  weak var viewInput: TokensListViewInput?
  weak var output: TokensListModuleOutput?
}

// MARK: - TokensListPresenterIntput

extension TokensListPresenter: TokensListPresenterInput {
  func viewDidLoad() {
    loadFakeSections()
  }
}

// MARK: - TokensListModuleInput

extension TokensListPresenter: TokensListModuleInput {}

// MARK: - Private

private extension TokensListPresenter {
  func loadFakeSections() {
    
    let tokenItems = (0...500).map { _ in
      TokenListTokenCell.Model()
    }
    let tokensSection = TokensListSection(type: .token,
                                          items: tokenItems)
    
    viewInput?.presentSections([tokensSection])
  }
}
