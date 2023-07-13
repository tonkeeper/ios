//
//  TokensListTokensListProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 26/05/2023.
//

import Foundation

protocol TokensListModuleOutput: AnyObject {
  func tokensListModuleInput(_ tokensList: TokensListModuleInput, didSelectItemAt indexPath: IndexPath)
}

protocol TokensListModuleInput: WalletContentPageInput {}

protocol TokensListPresenterInput {
  func viewDidLoad()
  func didSelectItemAt(indexPath: IndexPath)
}

protocol TokensListViewInput: AnyObject {
  func presentSections(_ sections: [TokensListSection])
}
