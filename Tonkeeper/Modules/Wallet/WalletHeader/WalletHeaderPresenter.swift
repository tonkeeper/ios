//
//  WalletHeaderPresenter.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import Foundation
import UIKit
import WalletCoreKeeper

final class WalletHeaderPresenter {
  
  // MARK: - Module
  
  weak var viewInput: WalletHeaderViewInput?
  weak var output: WalletHeaderModuleOutput?
}

// MARK: - WalletHeaderPresenterIntput

extension WalletHeaderPresenter: WalletHeaderPresenterInput {
  func viewDidLoad() {
    let buttonModels = createHeaderButtonModels()
    viewInput?.updateButtons(with: buttonModels)
  }
  
  func didTapAddressButton() {
    output?.didTapAddress()
  }
  
  func didTapScanQRButton() {
    output?.openQRScanner()
  }
}

// MARK: - WalletHeaderModuleInput

extension WalletHeaderPresenter: WalletHeaderModuleInput {
  func updateTitle(_ title: String) {
    viewInput?.updateTitle(title)
  }
  
  func updateWith(walletHeader: WalletBalanceModel.Header) {
    let headerModel = WalletHeaderView.Model(balance: walletHeader.amount, address: walletHeader.shortAddress)
    viewInput?.update(with: headerModel)
  }
  
  func updateConnectionState(_ model: WalletHeaderConnectionStatusView.Model?) {
    viewInput?.updateConnectionState(model)
  }
}

// MARK: - WalletHeaderPresenter

private extension WalletHeaderPresenter {
  func createHeaderButtonModels() -> [WalletHeaderButtonModel] {
    let types: [WalletHeaderButtonModel.ButtonType] = [.send, .receive, .buy]
    return types.map { type in
      let buttonModel = TKButton.Model(icon: type.icon)
      let iconButtonModel = IconButton.Model(buttonModel: buttonModel, title: type.title)
      let model = WalletHeaderButtonModel(viewModel: iconButtonModel) { [weak self] in
        self?.handleHeaderButtonAction(type: type)
      }
      return model
    }
  }
  
  func handleHeaderButtonAction(type: WalletHeaderButtonModel.ButtonType) {
    switch type {
    case .send:
      output?.didTapSendButton()
    case .receive:
      output?.didTapReceiveButton()
    case .buy:
      output?.didTapBuyButton()
    default:
      break
    }
  }
}
