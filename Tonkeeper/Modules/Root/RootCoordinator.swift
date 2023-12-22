//
//  RootCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

protocol RootCoordinatorOutput: AnyObject {
  func rootCoordinatorDidStartBiometry(_ coordinator: RootCoordinator)
  func rootCoordinatorDidFinishBiometry(_ coordinator: RootCoordinator)
}

final class RootCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: RootCoordinatorOutput?
  
  private let assembly: RootAssembly
  
  private weak var tabBarCoordinator: TabBarCoordinator?
  
  private var deeplink: Deeplink?
 
  init(router: NavigationRouter,
       assembly: RootAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
 
  override func start(deeplink: Deeplink?) {
    self.deeplink = deeplink
    if assembly.walletCoreAssembly.walletProvider.hasWallets {
      openAuth()
    } else {
      openOnboarding()
    }
  }
  
  override func handleDeeplink(_ deeplink: Deeplink) {
    if tabBarCoordinator == nil {
      self.deeplink = deeplink
    } else {
      tabBarCoordinator?.handleDeeplink(deeplink)
    }
  }
}

private extension RootCoordinator {
  func openTabBar() {
    let coordinator = assembly.tabBarCoordinator()
    self.tabBarCoordinator = coordinator
    coordinator.output = self
    router.setPresentables([(coordinator.router.rootViewController, nil)])
    addChild(coordinator)
    coordinator.start(deeplink: deeplink)
    self.deeplink = nil
  }
  
  func openOnboarding() {
    let coordinator = assembly.onboardingCoordinator(
      output: self,
      navigationRouter: router)
    addChild(coordinator)
    coordinator.start()
  }
  
  func openAuth() {
    let coordinator = assembly.authenticationCoordinator(navigationRouter: router)
    coordinator.output = self
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
    let navigationController = NavigationController()
    navigationController.isModalInPresentation = true
    navigationController.configureTransparentAppearance()
    let navigationRouter = NavigationRouter(rootViewController: navigationController)
    
    let importWalletCoordinator = assembly.importWalletCoordinator(navigationRouter: navigationRouter)
    importWalletCoordinator.output = self
    
    addChild(importWalletCoordinator)
    importWalletCoordinator.start()
    router.present(importWalletCoordinator.router.rootViewController)
  }
  
  func openCreateWallet() {
    let navigationController = NavigationController()
    navigationController.isModalInPresentation = true
    navigationController.configureTransparentAppearance()
    let navigationRouter = NavigationRouter(rootViewController: navigationController)
    
    let createWalletCoordinator = assembly.createWalletCoordinator(navigationRouter: navigationRouter)
    createWalletCoordinator.output = self
    
    addChild(createWalletCoordinator)
    createWalletCoordinator.start()
    router.present(createWalletCoordinator.router.rootViewController)
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
    router.dismiss { [weak self] in
      self?.openCreateWallet()
    }
  }
}

// MARK: - OnboardingCoordinatorOutput

extension RootCoordinator: OnboardingCoordinatorOutput {
  func onboardingCoordinatorDidTapGetStarted(_ coordinator: OnboardingCoordinator) {
    openCreateImportWallet()
  }
}

// MARK: - ImportWalletCoordinatorOutput

extension RootCoordinator: ImportWalletCoordinatorOutput {
  func importWalletCoordinatorDidClose(_ coordinator: ImportWalletCoordinator) {
    router.dismiss { [weak self] in
      self?.removeChild(coordinator)
    }
  }
  
  func importWalletCoordinatorDidImportWallet(_ coordinator: ImportWalletCoordinator) {
    openTabBar()
  }
}

// MARK: - CreateWalletCoordinatorOutput

extension RootCoordinator: CreateWalletCoordinatorOutput {
  func createWalletCoordinatorDidClose(_ coordinator: CreateWalletCoordinator) {
    router.dismiss { [weak self] in
      self?.removeChild(coordinator)
    }
  }
  
  func createWalletCoordinatorDidCreateWallet(_ coordinator: CreateWalletCoordinator) {
    openTabBar()
  }
}

// MARK: - PasscodeAuthCoordinatorOutput

extension RootCoordinator: PasscodeAuthCoordinatorOutput {
  func createPasscodeCoordinatorDidAuth(_ coordinator: PasscodeAuthCoordinator) {
    removeChild(coordinator)
    openTabBar()
  }
  
  func createPasscodeCoordinatorDidStartBiometry(_ coordinator: PasscodeAuthCoordinator) {
    output?.rootCoordinatorDidStartBiometry(self)
  }
  
  func createPasscodeCoordinatorDidFinishBiometry(_ coordinator: PasscodeAuthCoordinator) {
    output?.rootCoordinatorDidFinishBiometry(self)
  }
  
  func createPasscodeCoordinatorDidLogout(_ coordinator: PasscodeAuthCoordinator) {
    removeChild(coordinator)
    start(deeplink: nil)
  }
}

// MARK: - TabBarCoordinatorOutput

extension RootCoordinator: TabBarCoordinatorOutput {
  func tabBarCoordinatorDidLogout(_ coordinator: TabBarCoordinator) {
    removeChild(coordinator)
    start(deeplink: nil)
  }
}
