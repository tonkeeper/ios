//
//  ReceiveReceiveProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 05/06/2023.
//

import Foundation

protocol ReceiveModuleOutput: AnyObject {
  func receieveModuleDidTapCloseButton()
}

protocol ReceiveModuleInput: AnyObject {}

protocol ReceivePresenterInput {
  func viewDidLoad()
  func didTapSwipeButton()
}

protocol ReceiveViewInput: AnyObject {
  func updateView(model: ReceiveView.Model)
}
