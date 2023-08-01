//
//  SendCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit
import WalletCore
import BigInt

protocol SendCoordinatorOutput: AnyObject {
  func sendCoordinatorDidClose(_ coordinator: SendCoordinator)
}

final class SendCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: SendCoordinatorOutput?

  private let walletCoreAssembly: WalletCoreAssembly
  private let token: Token
  
  private var recipient: Recipient?
  private var itemTransferModel: ItemTransferModel?
  private var comment: String?
  
  private weak var sendRecipientInput: SendRecipientModuleInput?
  
  init(router: NavigationRouter,
       walletCoreAssembly: WalletCoreAssembly,
       token: Token,
       recipient: Recipient?) {
    self.walletCoreAssembly = walletCoreAssembly
    self.token = token
    self.recipient = recipient
    super.init(router: router)
  }
  
  override func start() {
    if let recipient = recipient {
      openWith(recipient: recipient)
    } else {
      openSendRecipient()
    }
  }
}

private extension SendCoordinator {
  func openSendRecipient() {
    let module = SendRecipientAssembly.module(
      sendRecipientController: walletCoreAssembly.sendRecipientController(),
      commentLengthValidator: DefaultSendRecipientCommentLengthValidator(),
      recipient: recipient,
      output: self
    )
    sendRecipientInput = module.input
    router.setPresentables([(module.view, nil)])
  }
  
  func openSendAmount(recipient: Recipient) {
    let module = SendAmountAssembly.module(recipient: recipient,
                                           inputCurrencyFormatter: .inputCurrencyFormatter,
                                           sendInputController: walletCoreAssembly.sendInputController,
                                           output: self)
    
    module.view.setupBackButton()
    router.push(presentable: module.view)
  }
  
  func openConfirmation() {
    guard let recipient = recipient,
          let itemTransferModel = itemTransferModel else { return }
    
    let module = SendConfirmationAssembly
      .module(
        recipient: recipient,
        itemTransferModel: itemTransferModel,
        comment: comment,
        sendController: walletCoreAssembly.sendController(),
        output: self)
    module.view.setupBackButton()
    router.push(presentable: module.view)
  }
  
  func openWith(recipient: Recipient) {
    let recipientModule = SendRecipientAssembly.module(
      sendRecipientController: walletCoreAssembly.sendRecipientController(),
      commentLengthValidator: DefaultSendRecipientCommentLengthValidator(),
      recipient: recipient,
      output: self
    )
    sendRecipientInput = recipientModule.input
    
    let amountModule = SendAmountAssembly.module(recipient: recipient,
                                                 inputCurrencyFormatter: .inputCurrencyFormatter,
                                                 sendInputController: walletCoreAssembly.sendInputController,
                                                 output: self)
    amountModule.view.setupBackButton()

    router.setPresentables([(recipientModule.view, nil), (amountModule.view, nil)])
  }
}

// MARK: - SendRecipientModuleOutput

extension SendCoordinator: SendRecipientModuleOutput {
  func sendRecipientModuleOpenQRScanner() {
    let module = QRScannerAssembly.qrScannerModule(output: self)
    router.present(module.view)
  }
  
  func sendRecipientModuleDidTapCloseButton() {
    output?.sendCoordinatorDidClose(self)
  }
  
  func sendRecipientModuleDidTapContinueButton(
    recipient: Recipient,
    comment: String?) {
      self.recipient = recipient
      self.comment = comment
      openSendAmount(recipient: recipient)
  }
}

// MARK: - SendAmountModuleOutput

extension SendCoordinator: SendAmountModuleOutput {
  func sendAmountModuleDidTapCloseButton() {
    output?.sendCoordinatorDidClose(self)
  }
  
  func sendAmountModuleDidEnterAmount(itemTransferModel: ItemTransferModel) {
    self.itemTransferModel = itemTransferModel
    self.openConfirmation()
  }
}

// MARK: - SendConfirmationModuleOutput

extension SendCoordinator: SendConfirmationModuleOutput {
  func sendConfirmationModuleDidTapCloseButton() {
    output?.sendCoordinatorDidClose(self)
  }
  
  func sendRecipientModuleDidFinish() {
    output?.sendCoordinatorDidClose(self)
  }
}

// MARK: - QRScannerModuleOutput

extension SendCoordinator: QRScannerModuleOutput {
  func qrScannerModuleDidFinish() {
    router.dismiss()
  }
  
  func didScanQrCode(with string: String) {
    router.dismiss()
    guard let deeplink = try? walletCoreAssembly.deeplinkParser.parse(string: string) else {
      return
    }

    switch deeplink {
    case let .ton(tonDeeplink):
      switch tonDeeplink {
      case let .transfer(address):
        sendRecipientInput?.setRecipient(Recipient(address: address, domain: nil))
      }
    }
  }
}
