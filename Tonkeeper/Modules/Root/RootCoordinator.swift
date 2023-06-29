//
//  RootCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

final class RootCoordinator: Coordinator<NavigationRouter> {
  
  private let assembly: RootAssembly
 
  init(router: NavigationRouter,
       assembly: RootAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    if assembly.walletCoreAssembly.keeperController.hasWallets {
      openTabBar()
    } else {
      openOnboarding()
    }
  }
}

private extension RootCoordinator {
  func openTabBar() {
    let coordinator = assembly.tabBarCoordinator()
    router.setPresentables([(coordinator.router.rootViewController, nil)])
    addChild(coordinator)
    coordinator.start()
  }
  
  func openOnboarding() {
    let coordinator = assembly.onboardingCoordinator(
      output: self,
      navigationRouter: router)
    addChild(coordinator)
    coordinator.start()
  }
  
  func openCreateImportWallet() {
    let module = SetupWalletAssembly.create(output: self)
    let modalCardContainerViewController = ModalCardContainerViewController(content: module.view)
    modalCardContainerViewController.headerSize = .small
    
    router.present(modalCardContainerViewController)
  }
  
  func openImportWallet() {
    let importWalletCoordinator = assembly.importWalletCoordinator(navigationRouter: router)
    addChild(importWalletCoordinator)
    importWalletCoordinator.start()
  }
}

// MARK: - SetupWalletModuleOutput

extension RootCoordinator: SetupWalletModuleOutput {
  func didTapImportWallet() {
    router.dismiss { [weak self] in
      self?.openImportWallet()
    }
  }
  
  func didTapCreateWallet() {
    router.dismiss { }
  }
}


// MARK: - OnboardingCoordinatorOutput

extension RootCoordinator: OnboardingCoordinatorOutput {
  func onboardingCoordinatorDidTapGetStarted(_ coordinator: OnboardingCoordinator) {
    openCreateImportWallet()
  }
}

