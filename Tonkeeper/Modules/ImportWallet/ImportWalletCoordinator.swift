//
//  ImportWalletCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit
import WalletCoreKeeper
import WalletCoreCore

protocol ImportWalletCoordinatorOutput: AnyObject {
  func importWalletCoordinatorDidClose(_ coordinator: ImportWalletCoordinator)
  func importWalletCoordinatorDidImportWallet(_ coordinator: ImportWalletCoordinator)
}

final class ImportWalletCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: ImportWalletCoordinatorOutput?
    
  private let assembly: ImportWalletAssembly
  
  private var importWalletClosure: ((Passcode) throws -> Void)?
  
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
    module.view.setupCloseRightButton { [weak self] in
      guard let self = self else { return }
      self.output?.importWalletCoordinatorDidClose(self)
    }
    router.push(presentable: module.view, dismiss: { [weak self] in
      guard let self = self else { return }
      self.output?.importWalletCoordinatorDidClose(self)
    })
  }
  
  func openCreatePasscode(walletImporter: WalletImporter) {
    importWalletClosure = { passcode in
      try walletImporter.importWallet(with: passcode)
    }
    
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
  func didInputMnemonic(_ mnemonic: [String]) {
    let walletImporter = WalletImporter(
      walletsController: assembly.walletCoreAssembly.walletsController,
      passcodeController: assembly.walletCoreAssembly.passcodeController,
      mnemonic: mnemonic
    )
    openCreatePasscode(walletImporter: walletImporter)
  }
}

// MARK: - CreatePasscodeCoordinatorOutput

extension ImportWalletCoordinator: CreatePasscodeCoordinatorOutput {
  func createPasscodeCoordinatorDidCreatePasscode(
    _ coordinator: CreatePasscodeCoordinator,
    passcode: Passcode
  ) {
    do {
      try importWalletClosure?(passcode)
      
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
      
    } catch {
      // TBD: handle wallet import failed
    }
  }
}

