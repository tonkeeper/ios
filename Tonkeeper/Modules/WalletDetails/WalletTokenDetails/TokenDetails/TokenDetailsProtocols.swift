//
//  TokenDetailsTokenDetailsProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 13/07/2023.
//

import Foundation

protocol TokenDetailsModuleOutput: AnyObject {}

protocol TokenDetailsModuleInput: AnyObject {}

protocol TokenDetailsPresenterInput {
  func viewDidLoad()
  func didPullToRefresh()
}

protocol TokenDetailsViewInput: AnyObject {
  func updateTitle(title: String)
  func updateHeader(model: TokenDetailsHeaderView.Model)
  func stopRefresh()
}
