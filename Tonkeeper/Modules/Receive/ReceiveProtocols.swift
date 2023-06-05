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
}

protocol ReceiveViewInput: AnyObject {}
