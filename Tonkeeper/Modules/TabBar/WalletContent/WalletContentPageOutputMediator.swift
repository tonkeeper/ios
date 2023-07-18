//
//  WalletContentPageOutputMediator.swift
//  Tonkeeper
//
//  Created by Grigory on 13.7.23..
//

import Foundation

final class WalletContentPageOutputMediator {
  
  weak var output: WalletContentPageOutput?
}

// MARK: - TokensListModuleInput

extension WalletContentPageOutputMediator: TokensListModuleOutput {
  func tokensListModuleInput(_ tokensList: TokensListModuleInput, didSelectItemAt indexPath: IndexPath) {
    output?.walletContentPageInput(tokensList, didSelectItemAt: indexPath)
  }
}

