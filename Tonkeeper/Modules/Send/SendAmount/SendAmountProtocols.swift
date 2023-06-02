//
//  SendAmountSendAmountProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation

protocol SendAmountModuleOutput: AnyObject {
  func sendAmountModuleDidTapCloseButton()
}

protocol SendAmountModuleInput: AnyObject {}

protocol SendAmountPresenterInput {
  func viewDidLoad()
  func didTapCloseButton()
  func didTapMaxButton()
}

protocol SendAmountViewInput: AnyObject {
  func updateTitleView(model: SendAmountTitleView.Model)
  func updateRemainingLabel(string: String?)
  func selectMaxButton()
  func deselectMaxButton()
}
