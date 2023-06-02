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
  var textFieldFormatController: TextFieldFormatController { get }
  
  func viewDidLoad()
  func didTapCloseButton()
  func didTapMaxButton()
  func didChangeAmountText(text: String?)
}

protocol SendAmountViewInput: AnyObject {
  func updateTitleView(model: SendAmountTitleView.Model)
  func updateRemainingLabel(attributedString: NSAttributedString?)
  func selectMaxButton()
  func deselectMaxButton()
  func updateInputCurrencyCode(_ code: String?)
  func updateInputValue(_ value: String?)
}
