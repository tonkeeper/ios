//
//  SettingsCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import Foundation

protocol SettingsCoordinatorOutput: AnyObject {
  func settingsCoordinatorDidLogout(_ settingsCoordinator: SettingsCoordinator)
}

final class SettingsCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: SettingsCoordinatorOutput?
  
  private let walletCoreAssembly: WalletCoreAssembly
  private let passcodeAssembly: PasscodeAssembly
  
  private var confirmationContinuation: CheckedContinuation<Bool, Never>?
  
  init(router: NavigationRouter,
       walletCoreAssembly: WalletCoreAssembly,
       passcodeAssembly: PasscodeAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
    self.passcodeAssembly = passcodeAssembly
    super.init(router: router)
  }
  
  override func start() {
    openSettingsList()
  }
}

private extension SettingsCoordinator {
  func openSettingsList() {
    let module = SettingsListAssembly.module(
      settingsController: walletCoreAssembly.settingsController(),
      logoutController: walletCoreAssembly.logoutController(),
      urlOpener: walletCoreAssembly.coreAssembly.urlOpener(),
      infoProvider: walletCoreAssembly.coreAssembly.infoProvider,
      appStoreReviewer: walletCoreAssembly.coreAssembly.appStoreReviewer(),
      output: self
    )
    router.setPresentables([(module.view, nil)])
  }
  
  func openManuallyBackup() {
    let coordinator = SettingsManuallyBackupCoordinator(
      router: router,
      walletCoreAssembly: walletCoreAssembly
    )
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didFinish = {
      
    }
    
    addChild(coordinator)
    coordinator.start()
  }
}

// MARK: - SettingsListModuleOutput

extension SettingsCoordinator: SettingsListModuleOutput {
  func settingsListDidSelectCurrencySetting(_ settingsList: SettingsListModuleInput) {
    let module = SettingsCurrencyPickerAssembly.module(
      settingsController: walletCoreAssembly.settingsController(),
      output: self
    )
    module.view.setupBackButton()
    router.push(presentable: module.view)
  }
  
  func settingsListDidSelectSecuritySetting(_ settingsList: SettingsListModuleInput) {
    let module = SettingsSecurityAssembly.module(
      biometryAuthentificator: BiometryAuthentificator(),
      settingsController: walletCoreAssembly.settingsController(),
      output: self)
    
    module.view.setupBackButton()
    router.push(presentable: module.view)
  }
  
  func settingsListDidSelectBackupSetting(_ settingsList: SettingsListModuleInput) {
    let module = SettingsBackupAssembly.module()
    
    module.1.didTapShowRecoveryPhrase = { [weak self] in
      self?.settingsSecurityDidSelectShowRecoveryPhrase()
    }
    
    module.1.didTapBackupManually = { [weak self] in
      self?.openManuallyBackup()
    }
    
    module.1.confirmation = { [weak self] in
      await self?.settingsSecurityConfirmation() ?? false
    }
    
    module.0.setupBackButton()
    router.push(presentable: module.0)
  }
  
  func settingsListDidLogout(_ settingsList: SettingsListModuleInput) {
    output?.settingsCoordinatorDidLogout(self)
  }
}

// MARK: - SettingsSecurityModuleOutput

extension SettingsCoordinator: SettingsSecurityModuleOutput {
  func settingsSecurityConfirmation() async -> Bool {
    return await withCheckedContinuation { [weak self] continuation in
      guard let self = self else { return }
      self.confirmationContinuation = continuation
      Task {
        await MainActor.run {
          let coordinator = self.passcodeAssembly.passcodeConfirmationCoordinator()
          coordinator.output = self
          
          self.addChild(coordinator)
          coordinator.start()
          self.router.present(coordinator.router.rootViewController)
        }
      }
    }
  }
  
  func settingsSecurityDidSelectShowRecoveryPhrase() {
    let module = SettingsRecoveryPhraseAssembly.module(
      walletProvider: walletCoreAssembly.walletProvider,
      output: self
    )
    module.view.setupBackButton()
    router.push(presentable: module.view)
  }
  
  func settingsSecurityDidSelectChangePasscode() {
    let navigationController = NavigationController()
    navigationController.configureDefaultAppearance()
    let changePasscodeCoordinator = SettingsChangePasscodeCoordinator(
      router: NavigationRouter(rootViewController: navigationController),
      walletCoreAssembly: walletCoreAssembly
    )
    
    changePasscodeCoordinator.didClose = { [weak self, unowned changePasscodeCoordinator] in
      self?.router.rootViewController.dismiss(animated: true)
      self?.removeChild(changePasscodeCoordinator)
    }
    
    changePasscodeCoordinator.didChangePasscode = { [weak self, unowned changePasscodeCoordinator] in
      self?.router.rootViewController.dismiss(animated: true)
      self?.removeChild(changePasscodeCoordinator)
      TapticGenerator.generateSuccessFeedback()
      ToastController.showToast(configuration: ToastController.Configuration(title: "Passcode changed"))
    }
    
    changePasscodeCoordinator.didFailedToChangePasscode = { [weak self, unowned changePasscodeCoordinator] in
      self?.router.rootViewController.dismiss(animated: true)
      self?.removeChild(changePasscodeCoordinator)
      TapticGenerator.generateFailureFeedback()
      ToastController.showToast(configuration: .failed)
    }
    
    addChild(changePasscodeCoordinator)
    changePasscodeCoordinator.start()
    
    router.rootViewController.present(navigationController, animated: true)
  }
}

extension SettingsCoordinator: PasscodeConfirmationCoordinatorOutput {
  func passcodeConfirmationCoordinatorDidConfirm(_ coordinator: PasscodeConfirmationCoordinator) {
    router.dismiss()
    removeChild(coordinator)
    confirmationContinuation?.resume(returning: true)
    confirmationContinuation = nil
  }
  
  func passcodeConfirmationCoordinatorDidClose(_ coordinator: PasscodeConfirmationCoordinator) {
    router.dismiss()
    removeChild(coordinator)
    confirmationContinuation?.resume(returning: false)
    confirmationContinuation = nil
  }
}

extension SettingsCoordinator: SettingsRecoveryPhraseModuleOutput {}
