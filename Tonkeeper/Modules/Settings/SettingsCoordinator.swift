//
//  SettingsCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import Foundation

final class SettingsCoordinator: Coordinator<NavigationRouter> {
  
  private let assembly: SettingsAssembly
  
  init(router: NavigationRouter,
       assembly: SettingsAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    openSettingsList()
  }
}

private extension SettingsCoordinator {
  func openSettingsList() {
    let module = SettingsListAssembly.module(output: self)
    router.setPresentables([(module.view, nil)])
  }
}

extension SettingsCoordinator: SettingsListModuleOutput {
  
}
