//
//  BrowserCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import Foundation

final class BrowserCoordinator: Coordinator<NavigationRouter> {
  
  private let assembly: BrowserAssembly
  
  init(router: NavigationRouter,
       assembly: BrowserAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
}
