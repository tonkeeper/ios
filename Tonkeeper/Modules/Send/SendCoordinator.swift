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
  func didTapCloseButton() {
    output?.sendCoordinatorDidClose(self)
  }
}

// MARK: - SendAmountModuleOutput

extension SendCoordinator: SendAmountModuleOutput {}
