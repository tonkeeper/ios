//
//  SendAmountSendAmountProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation
import WalletCore

protocol SendAmountModuleOutput: AnyObject {
  func sendAmountModuleDidTapCloseButton()
  func sendAmountModuleDidPrepareTransaction(_ sendTransactionModel: SendTransactionModel)
}

protocol SendAmountModuleInput: AnyObject {}

protocol SendAmountPresenterInput {
  var amountInputFormatController: AmountInputFormatController { get }
  
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
  func updateContinueButtonAvailability(_ isAvailable: Bool)
}
