//
//  SettingsAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import Foundation

final class SettingsAssembly {
  
  func coordinator(router: NavigationRouter) -> SettingsCoordinator {
    SettingsCoordinator(router: router, assembly: SettingsAssembly())
  }
}
