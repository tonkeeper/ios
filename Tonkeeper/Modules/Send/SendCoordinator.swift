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
  
  init(router: NavigationRouter,
       assembly: SendAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    openSendRecipient()
  }
}

private extension SendCoordinator {
  func openSendRecipient() {
    let module = assembly.sendRecipientModule(output: self)
    router.setPresentables([(module.view, nil)])
  }
  
  func openSendAmount() {
    let module = assembly.sendAmountModule(output: self)
    module.view.setupBackButton()
    router.push(presentable: module.view)
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
}

// MARK: - QRScannerModuleOutput

extension SendCoordinator: QRScannerModuleOutput {
  func qrScannerModuleDidFinish() {
    router.dismiss()
  }
}
