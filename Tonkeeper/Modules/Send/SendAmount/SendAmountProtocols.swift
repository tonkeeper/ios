//
//  SendAmountSendAmountProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation

protocol SendAmountModuleOutput: AnyObject {
  func sendAmountModuleDidTapCloseButton()
  func sendAmountModuleDidTapContinueButton()
}

protocol SendAmountModuleInput: AnyObject {}

protocol SendAmountPresenterInput {
  var textFieldFormatController: TextFieldFormatController { get }
  
  func viewDidLoad()
  func didTapCloseButton()
  func didTapSwapButton()
  func didTapMaxButton()
  func didChangeAmountText(text: String?)
  func didTapContinueButton()
}

protocol SendAmountViewInput: AnyObject {
  func updateTitleView(model: SendAmountTitleView.Model)
  func updateRemainingLabel(attributedString: NSAttributedString?)
  func selectMaxButton()
  func deselectMaxButton()
  func updatePrimaryCurrency(_ value: String?, currencyCode: String?)
  func updateSecondaryCurrency(_ string: String?)
}
