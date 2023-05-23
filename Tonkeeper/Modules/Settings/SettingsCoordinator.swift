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
}
