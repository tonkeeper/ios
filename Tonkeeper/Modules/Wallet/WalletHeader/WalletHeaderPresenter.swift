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

extension WalletHeaderPresenter: WalletHeaderPresenterInput {}

// MARK: - WalletHeaderModuleInput

extension WalletHeaderPresenter: WalletHeaderModuleInput {}
