//
//  SendCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit

final class SendCoordinator: Coordinator<NavigationRouter> {
  
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
    router.push(presentable: module.view)
  }
}

// MARK: - SendRecipientModuleOutput

extension SendCoordinator: SendRecipientModuleOutput {}

// MARK: - SendAmountModuleOutput

extension SendCoordinator: SendAmountModuleOutput {}
