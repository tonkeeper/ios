//
//  SendCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit

protocol SendCoordinatorOutput: AnyObject {
  func sendCoordinatorDidClose(_ coordinator: SendCoordinator)
}

final class SendCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: SendCoordinatorOutput?
  
  private let assembly: SendAssembly
  private var address: String?
  
  private weak var sendRecipientInput: SendRecipientModuleInput?
  
  init(router: NavigationRouter,
       assembly: SendAssembly,
       address: String?) {
    self.assembly = assembly
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
    let module = assembly.sendRecipientModule(
      output: self,
      address: address
    )
    sendRecipientInput = module.input
    router.setPresentables([(module.view, nil)])
  }
  
  func openSendAmount() {
    let module = assembly.sendAmountModule(output: self)
    module.view.setupBackButton()
    router.push(presentable: module.view)
  }
  
  func openConfirmation() {
    let module = assembly.sendConfirmationModule(output: self)
    module.view.setupBackButton()
    router.push(presentable: module.view)
  }
  
  func openWith(address: String) {
    let recipientModule = assembly.sendRecipientModule(
      output: self,
      address: address
    )
    sendRecipientInput = recipientModule.input
    
    let amountModule = assembly.sendAmountModule(output: self)
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
  
  func sendRecipientModuleDidTapContinueButton() {
    openSendAmount()
  }
}

// MARK: - SendAmountModuleOutput

extension SendCoordinator: SendAmountModuleOutput {
  func sendAmountModuleDidTapCloseButton() {
    output?.sendCoordinatorDidClose(self)
  }
  
  func sendAmountModuleDidTapContinueButton() {
    openConfirmation()
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
