//
//  TokensListTokensListProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 26/05/2023.
//

import Foundation

protocol TokensListModuleOutput: AnyObject {}

protocol TokensListModuleInput: AnyObject {}

protocol TokensListPresenterInput {
  func viewDidLoad()
}

protocol TokensListViewInput: AnyObject {}