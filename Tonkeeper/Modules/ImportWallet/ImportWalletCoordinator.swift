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
    successViewController.modalPresentationStyle = .fullScreen
    successViewController.modalTransitionStyle = .crossDissolve
    successViewController.didFinishAnimation = { [weak self] in
      self?.router.dismiss(completion: { [weak self] in
        guard let self = self else { return }
        self.output?.importWalletCoordinatorDidClose(self)
      })
    }
    router.rootViewController.present(successViewController, animated: true) { [weak self] in
      guard let self = self else { return }
      self.output?.importWalletCoordinatorDidImportWallet(self)
    }
  }
}

