//
//  SettingsCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import Foundation

final class SettingsCoordinator: Coordinator<NavigationRouter> {
  
  private let walletCoreAssembly: WalletCoreAssembly
  
  init(router: NavigationRouter,
       walletCoreAssembly: WalletCoreAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
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
      output: self
    )
    router.setPresentables([(module.view, nil)])
  }
}

extension SettingsCoordinator: SettingsListModuleOutput {
  
}
