//
//  ActivityRootActivityRootProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import Foundation

protocol ActivityRootModuleOutput: AnyObject {
  func didTapReceiveButton()
  func didSelectTransaction()
}

protocol ActivityRootModuleInput: AnyObject {}

protocol ActivityRootPresenterInput {
  func viewDidLoad()
}

protocol ActivityRootViewInput: AnyObject {
  func showEmptyState()
  func updateTitle(_ title: String)
}