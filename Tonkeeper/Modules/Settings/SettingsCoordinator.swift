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
      keeperController: walletCoreAssembly.keeperController,
      output: self
    )
    module.view.setupBackButton()
    router.push(presentable: module.view)
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
