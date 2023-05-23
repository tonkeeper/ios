//
//  ActivityCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

final class ActivityCoordinator: Coordinator<NavigationRouter> {
  
  private let assembly: ActivityAssembly
  
  init(router: NavigationRouter,
       assembly: ActivityAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
}
