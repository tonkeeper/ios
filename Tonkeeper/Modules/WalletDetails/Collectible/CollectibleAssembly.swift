//
//  CollectibleAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 21.8.23..
//

import Foundation

struct CollectibleAssembly {
  func coordinator(router: NavigationRouter) -> CollectibleCoordinator {
    return CollectibleCoordinator(router: router)
  }
}
