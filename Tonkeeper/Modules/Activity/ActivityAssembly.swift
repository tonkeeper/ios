//
//  ActivityAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

struct ActivityAssembly {
  private let receiveAssembly: ReceiveAssembly
  
  init(receiveAssembly: ReceiveAssembly) {
    self.receiveAssembly = receiveAssembly
  }
 
  func coordinator(router: NavigationRouter) -> ActivityCoordinator {
    ActivityCoordinator(router: router, recieveAssembly: receiveAssembly)
  }
}
