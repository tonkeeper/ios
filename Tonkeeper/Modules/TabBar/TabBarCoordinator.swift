//
//  TabBarCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class TabBarCoordinator: Coordinator<TabBarRouter> {
  
  private let assembly: TabBarAssembly
  
  init(router: TabBarRouter,
       assembly: TabBarAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
}
