//
//  ImportWalletCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

protocol ImportWalletCoordinatorOutput: AnyObject {
  func importWalletCoordinatorDidClose(_ coordinator: ImportWalletCoordinator)
}

final class ImportWalletCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: ImportWalletCoordinatorOutput?
    
  private let assembly: ImportWalletAssembly
  
  init(router: NavigationRouter,
       assembly: ImportWalletAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    openEnterMnemonic()
  }
}

private extension ImportWalletCoordinator {
  func openEnterMnemonic() {
    let module = assembly.enterMnemonic(output: self)
    router.push(presentable: module.view, dismiss: { [weak self] in
      guard let self = self else { return }
      self.output?.importWalletCoordinatorDidClose(self)
    })
  }
}

// MARK: - EnterMnemonicModuleOutput

extension ImportWalletCoordinator: EnterMnemonicModuleOutput {}

