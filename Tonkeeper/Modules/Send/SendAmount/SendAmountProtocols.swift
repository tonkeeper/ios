//
//  SendAmountSendAmountProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import Foundation
import WalletCoreKeeper

protocol SendAmountModuleOutput: AnyObject {
  func sendAmountModuleDidTapCloseButton()
  func sendAmountModuleDidEnterAmount(tokenTransferModel: TokenTransferModel)
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
  func didTapSelectTokenButton()
  func didSelectToken(at index: Int)
}

protocol SendAmountViewInput: AnyObject {
  func updateTitleView(model: SendAmountTitleView.Model)
  func updateRemainingLabel(attributedString: NSAttributedString?)
  func selectMaxButton()
  func deselectMaxButton()
  func updatePrimaryCurrency(_ value: String?, currencyCode: String?)
  func updateSecondaryCurrency(_ string: String?)
  func updateContinueButtonAvailability(_ isAvailable: Bool)
  func showActivity()
  func hideActivity()
  func showMenu(items: [TKMenuItem])
  func showTokenSelectionButton(_ code: String)
  func hideTokenSelectionButton()
}
