//
//  CreateWalletCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 30.6.23..
//

import UIKit
import WalletCore

protocol CreateWalletCoordinatorOutput: AnyObject {
  func createWalletCoordinatorDidClose(_ coordinator: CreateWalletCoordinator)
  func createWalletCoordinatorDidCreateWallet(_ coordinator: CreateWalletCoordinator)
}

final class CreateWalletCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: CreateWalletCoordinatorOutput?
    
  private let assembly: CreateWalletAssembly
  private let walletCreator: WalletCreator
  
  init(router: NavigationRouter,
       assembly: CreateWalletAssembly) {
    self.assembly = assembly
    self.walletCreator = WalletCreator(
      keeperController: assembly.walletCoreAssembly.keeperController,
      passcodeController: assembly.walletCoreAssembly.passcodeController
    )
    super.init(router: router)
  }
  
  override func start() {
    createWallet()
  }
}

// MARK: - Private

private extension CreateWalletCoordinator {
  func createWallet() {
    let successViewController = SuccessViewController(configuration: .walletCreation)
    successViewController.modalPresentationStyle = .fullScreen
    successViewController.didFinishAnimation = { [weak self] in
      self?.openCreatePasscode()
    }
    router.setPresentables([(successViewController, nil)])
  }
  
  func openCreatePasscode() {
    let coordinator = assembly.createPasscodeCoordinator(router: router)
    coordinator.output = self
    coordinator.start()
    addChild(coordinator)
    
    guard let initialPresentable = coordinator.initialPresentable else { return }
    router.setPresentables([(initialPresentable, nil)])
  }
}

// MARK: - CreatePasscodeCoordinatorOutput

extension CreateWalletCoordinator: CreatePasscodeCoordinatorOutput {
  func createPasscodeCoordinatorDidFinish(_ coordinator: CreatePasscodeCoordinator) {
    removeChild(coordinator)
  }
  
  func createPasscodeCoordinatorDidCreatePasscode(
    _ coordinator: CreatePasscodeCoordinator,
    passcode: Passcode
  ) {
    do {
      try walletCreator.create(with: passcode)
      
      removeChild(coordinator)
      
      let successViewController = SuccessViewController(configuration: .walletImport)
      successViewController.didFinishAnimation = { [weak self] in
        self?.router.dismiss(completion: { [weak self] in
          guard let self = self else { return }
          self.output?.createWalletCoordinatorDidClose(self)
        })
      }
      
      router.push(presentable: successViewController, completion:  { [weak self] in
        guard let self = self else { return }
        self.output?.createWalletCoordinatorDidCreateWallet(self)
      })
    } catch {
      // TBD: handle wallet creation failed
    }
  }
}

