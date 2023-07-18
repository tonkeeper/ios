//
//  SendCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit
import WalletCore

protocol SendCoordinatorOutput: AnyObject {
  func sendCoordinatorDidClose(_ coordinator: SendCoordinator)
}

final class SendCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: SendCoordinatorOutput?

  private let assembly: SendAssembly
  private let walletCoreAssembly: WalletCoreAssembly
  private let token: Token
  private var address: String?
  
  private weak var sendRecipientInput: SendRecipientModuleInput?
  
  init(router: NavigationRouter,
       assembly: SendAssembly,
       walletCoreAssembly: WalletCoreAssembly,
       token: Token,
       address: String?) {
    self.assembly = assembly
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
      commentLengthValidator: DefaultSendRecipientCommentLengthValidator(),
      addressValidator: walletCoreAssembly.addressValidator,
      address: address,
      output: self
    )
    sendRecipientInput = module.input
    router.setPresentables([(module.view, nil)])
  }
  
  func openSendAmount(address: String,
                      comment: String?) {
    let module = SendAmountAssembly.module(address: address,
                                           comment: comment,
                                           inputCurrencyFormatter: .inputCurrencyFormatter,
                                           sendInputController: walletCoreAssembly.sendInputController,
                                           sendController: walletCoreAssembly.sendController(),
                                           output: self)
    module.view.setupBackButton()
    router.push(presentable: module.view)
  }
  
  func openConfirmation(transactionModel: SendTransactionModel) {
    let module = SendConfirmationAssembly.module(transactionModel: transactionModel,
                                                 sendController: walletCoreAssembly.sendController(),
                                                 output: self)
    module.view.setupBackButton()
    router.push(presentable: module.view)
  }
  
  func openWith(address: String) {
    let recipientModule = SendRecipientAssembly.module(
      commentLengthValidator: DefaultSendRecipientCommentLengthValidator(),
      addressValidator: walletCoreAssembly.addressValidator,
      address: address,
      output: self
    )
    sendRecipientInput = recipientModule.input
    
    let amountModule = SendAmountAssembly.module(address: address,
                                                 comment: nil,
                                                 inputCurrencyFormatter: .inputCurrencyFormatter,
                                                 sendInputController: walletCoreAssembly.sendInputController,
                                                 sendController: walletCoreAssembly.sendController(),
                                                 output: self)
    amountModule.view.setupBackButton()

    router.setPresentables([(recipientModule.view, nil), (amountModule.view, nil)])
  }
}

// MARK: - SendRecipientModuleOutput

extension SendCoordinator: SendRecipientModuleOutput {
  func sendRecipientModuleOpenQRScanner() {
    let module = assembly.qrScannerAssembly.qrScannerModule(output: self)
    router.present(module.view)
  }
  
  func sendRecipientModuleDidTapCloseButton() {
    output?.sendCoordinatorDidClose(self)
  }
  
  func sendRecipientModuleDidTapContinueButton(
    address: String,
    comment: String?
  ) {
    openSendAmount(address: address, comment: comment)
  }
}

// MARK: - SendAmountModuleOutput

extension SendCoordinator: SendAmountModuleOutput {
  func sendAmountModuleDidTapCloseButton() {
    output?.sendCoordinatorDidClose(self)
  }
  
  func sendAmountModuleDidPrepareTransaction(_ sendTransactionModel: SendTransactionModel) {
    openConfirmation(transactionModel: sendTransactionModel)
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
    guard let deeplink = try? assembly.deeplinkParser.parse(string: string) else {
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
