//
//  WalletContentWalletContentPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/05/2023.
//

import Foundation

final class WalletContentPresenter {
  
  // MARK: - Module
  
  weak var viewInput: WalletContentViewInput?
  weak var output: WalletContentModuleOutput?
}

// MARK: - WalletContentPresenterIntput

extension WalletContentPresenter: WalletContentPresenterInput {
  func viewDidLoad() {}
}

// MARK: - WalletContentModuleInput

extension WalletContentPresenter: WalletContentModuleInput {}

// MARK: - Private

private extension WalletContentPresenter {}
