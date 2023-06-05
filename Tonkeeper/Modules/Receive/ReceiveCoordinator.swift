//
//  ReceiveCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 5.6.23..
//

import UIKit

final class ReceiveCoordinator: Coordinator<NavigationRouter> {
  
  private let assembly: ReceiveAssembly
  
  init(router: NavigationRouter,
       assembly: ReceiveAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
}

