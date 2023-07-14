//
//  TokenDetailsTokenDetailsPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 13/07/2023.
//

import Foundation
import WalletCore

final class TokenDetailsPresenter {
  
  // MARK: - Module
  
  weak var viewInput: TokenDetailsViewInput?
  weak var output: TokenDetailsModuleOutput?
  
  // MARK: - Dependecies
  
  private let tokenDetailsController: WalletCore.TokenDetailsController
  
  // MARK: - Init
  
  init(tokenDetailsController: WalletCore.TokenDetailsController) {
    self.tokenDetailsController = tokenDetailsController
  }
}

// MARK: - TokenDetailsPresenterIntput

extension TokenDetailsPresenter: TokenDetailsPresenterInput {
  func viewDidLoad() {
    updateHeader()
  }
  
  func didPullToRefresh() {
    refreshContent()
  }
}

// MARK: - TokenDetailsModuleInput

extension TokenDetailsPresenter: TokenDetailsModuleInput {}

// MARK: - Private

private extension TokenDetailsPresenter {
  func updateHeader() {
    do {
      let header = try tokenDetailsController.getTokenHeader()
      let tokenDetailsHeaderViewModel = TokenDetailsHeaderView.Model(
        amount: header.amount,
        fiatAmount: header.fiatAmount,
        fiatPrice: header.price,
        image: .with(image: header.image))
      viewInput?.updateTitle(title: header.name)
      viewInput?.updateHeader(model: tokenDetailsHeaderViewModel)
    } catch {
      
    }
  }
  
  func refreshContent() {
    Task {
      do {
        try await tokenDetailsController.reloadContent()
        Task { @MainActor in
          updateHeader()
          viewInput?.stopRefresh()
        }
      } catch {
        Task { @MainActor in
          viewInput?.stopRefresh()
        }
      }
    }
  }
}
