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
  
  private var address: String?
  private var itemTransferModel: ItemTransferModel?
  private var comment: String?
  
  private weak var sendRecipientInput: SendRecipientModuleInput?
  
  init(router: NavigationRouter,
       walletCoreAssembly: WalletCoreAssembly,
       token: Token,
       address: String?) {
    self.walletCoreAssembly = walletCoreAssembly
    self.token = token
    self.address = address
    super.init(router: router)
  }
  
  override func start() {
    if let address = address {
      openWith(address: address)
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
      address: address,
      output: self
    )
    sendRecipientInput = module.input
    router.setPresentables([(module.view, nil)])
  }
  
  func openSendAmount() {
    let module = SendAmountAssembly.module(address: address ?? "",
                                           inputCurrencyFormatter: .inputCurrencyFormatter,
                                           sendInputController: walletCoreAssembly.sendInputController,
                                           output: self)
    
    module.view.setupBackButton()
    router.push(presentable: module.view)
  }
  
  func openConfirmation() {
    guard let address = address,
          let itemTransferModel = itemTransferModel else { return }
    
    let module = SendConfirmationAssembly
      .module(
        address: address,
        itemTransferModel: itemTransferModel,
        comment: comment,
        sendController: walletCoreAssembly.sendController(),
        output: self)
    module.view.setupBackButton()
    router.push(presentable: module.view)
  }
  
  func openWith(address: String) {
    let recipientModule = SendRecipientAssembly.module(
      sendRecipientController: walletCoreAssembly.sendRecipientController(),
      commentLengthValidator: DefaultSendRecipientCommentLengthValidator(),
      address: address,
      output: self
    )
    sendRecipientInput = recipientModule.input
    
    let amountModule = SendAmountAssembly.module(address: address,
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
    address: String,
    comment: String?
  ) {
    self.address = address
    self.comment = comment
    openSendAmount()
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
        sendRecipientInput?.setAddress(address)
      }
    }
  }
}
