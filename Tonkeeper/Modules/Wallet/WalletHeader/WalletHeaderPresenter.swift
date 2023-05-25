//
//  WalletHeaderPresenter.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import Foundation

final class WalletHeaderPresenter {
  
  // MARK: - Module
  
  weak var viewInput: WalletHeaderViewInput?
  weak var output: WalletHeaderModuleOutput?
}

// MARK: - WalletHeaderPresenterIntput

extension WalletHeaderPresenter: WalletHeaderPresenterInput {
  func viewDidLoad() {
    let model = WalletHeaderView.Model(balance: "$24,374",
                                       address: "EQF2…G21Z")
    viewInput?.update(with: model)
  }
  
  func didTapAddressButton() {}
}

// MARK: - WalletHeaderModuleInput

extension WalletHeaderPresenter: WalletHeaderModuleInput {}
