//
//  ImportWalletCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

protocol ImportWalletCoordinatorOutput: AnyObject {
  func importWalletCoordinatorDidClose(_ coordinator: ImportWalletCoordinator)
  func importWalletCoordinatorDidImportWallet(_ coordinator: ImportWalletCoordinator)
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
    module.view.setupCloseButton { [weak self] in
      guard let self = self else { return }
      self.output?.importWalletCoordinatorDidClose(self)
    }
    router.push(presentable: module.view, dismiss: { [weak self] in
      guard let self = self else { return }
      self.output?.importWalletCoordinatorDidClose(self)
    })
  }
  
  func openCreatePasscode() {
    let coordinator = assembly.createPasscodeCoordinator(router: router)
    coordinator.output = self
    coordinator.start()
    addChild(coordinator)
    
    guard let initialPresentable = coordinator.initialPresentable else { return }
    initialPresentable.setupBackButton()
    router.push(presentable: initialPresentable, dismiss: { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    })
  }
}

// MARK: - EnterMnemonicModuleOutput

extension ImportWalletCoordinator: EnterMnemonicModuleOutput {
  func didInputMnemonic() {
    openCreatePasscode()
  }
}

// MARK: - CreatePasscodeCoordinatorOutput

extension ImportWalletCoordinator: CreatePasscodeCoordinatorOutput {
  func createPasscodeCoordinatorDidFinish(_ coordinator: CreatePasscodeCoordinator) {
    removeChild(coordinator)
  }
  
  func createPasscodeCoordinatorDidCreatePasscode(_ coordinator: CreatePasscodeCoordinator) {
    removeChild(coordinator)
    
    let successViewController = SuccessViewController(configuration: .walletImport)
    successViewController.didFinishAnimation = { [weak self] in
      guard let self = self else { return }
      self.output?.importWalletCoordinatorDidClose(self)
    }
    router.push(presentable: successViewController, completion:  { [weak self] in
      guard let self = self else { return }
      self.output?.importWalletCoordinatorDidImportWallet(self)
    })
  }
}

