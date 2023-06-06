//
//  ActivityEmptyActivityEmptyProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import Foundation

protocol ActivityEmptyModuleOutput: AnyObject {
  func didTapReceiveButton()
}

protocol ActivityEmptyModuleInput: AnyObject {}

protocol ActivityEmptyPresenterInput {
  func viewDidLoad()
  func didTapReceiveButton()
}

protocol ActivityEmptyViewInput: AnyObject {
  func updateView(model: ActivityEmptyView.Model)
}
