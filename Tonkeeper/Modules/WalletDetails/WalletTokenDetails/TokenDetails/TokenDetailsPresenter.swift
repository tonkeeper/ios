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
    refreshContent()
  }
  
  func didPullToRefresh() {
    refreshContent()
  }
}

// MARK: - TokenDetailsModuleInput

extension TokenDetailsPresenter: TokenDetailsModuleInput {}

// MARK: - TokenDetailsTonControllerOutput

extension TokenDetailsPresenter {
  func handleTonRecieve() {
    output?.didTapTonReceive()
  }
  
  func handleTonSend() {
    output?.didTapTonSend()
  }
  
  func handleTonSwap() {
    output?.didTapTopSwap()
  }
  
  func handleTonBuy() {
    output?.didTapTonBuy()
  }
}

// MARK: - TokenDetailsTokenControllerOutput

extension TokenDetailsPresenter {
  func handleTokenRecieve(tokenInfo: TokenInfo) {
    output?.didTapTokenReceive(tokenInfo: tokenInfo)
  }
  
  func handleTokenSend(tokenInfo: TokenInfo) {
    output?.didTapTokenSend(tokenInfo: tokenInfo)
  }
  
  func handleTokenSwap(tokenInfo: TokenInfo) {
    output?.didTapTokenSwap(tokenInfo: tokenInfo)
  }
}
  

// MARK: - Private

private extension TokenDetailsPresenter {
  func updateHeader() {
    guard let header = try? tokenDetailsController.getTokenHeader() else { return }

    let buttonsRowButtons: [ButtonsRowView.Model.ButtonModel] = header.buttons.map {
      let buttonRowButtonType: ButtonsRowView.Model.ButtonType
      switch $0 {
      case .buy:
        buttonRowButtonType = .buy
      case .send:
        buttonRowButtonType = .send
      case .receive:
        buttonRowButtonType = .receive
      case .swap:
        buttonRowButtonType = .swap
      }
      
      return ButtonsRowView.Model.ButtonModel(type: buttonRowButtonType) { [weak self] in
        self?.handleButtonsRowButtonAction(type: buttonRowButtonType)
      }
    }
    
    let tokenDetailsHeaderViewModel = TokenDetailsHeaderView.Model(
      amount: header.amount,
      fiatAmount: header.fiatAmount,
      fiatPrice: header.price,
      image: .with(image: header.image),
      buttonRowModel: .init(buttons: buttonsRowButtons))
    viewInput?.updateTitle(title: header.name)
    viewInput?.updateHeader(model: tokenDetailsHeaderViewModel)
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
  
  func handleButtonsRowButtonAction(type: ButtonsRowView.Model.ButtonType) {
    switch type {
    case .receive:
      tokenDetailsController.handleRecieve()
    case .swap:
      tokenDetailsController.handleSwap()
    case .send:
      tokenDetailsController.handleSend()
    case .buy:
      tokenDetailsController.handleBuy()
    case .sell:
      break
    }
  }
}
