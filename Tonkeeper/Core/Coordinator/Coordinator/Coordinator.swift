//
//  Coordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import Foundation

protocol CoordinatorProtocol: AnyObject {
  func addChild(_ child: CoordinatorProtocol)
  func removeChild(_ child: CoordinatorProtocol)
  func start()
}

class Coordinator<Router: RouterProtocol>: CoordinatorProtocol {
  
  let router: any RouterProtocol
  
  private var children = [CoordinatorProtocol]()
  
  init(router: any RouterProtocol) {
    self.router = router
  }
  
  func addChild(_ child: CoordinatorProtocol) {
    guard !children.contains(where: { $0 === child }) else { return }
    children.append(child)
  }
  
  func removeChild(_ child: CoordinatorProtocol) {
    guard !children.isEmpty else { return }
    children.removeAll(where: { $0 === child })
  }
  
  func start() {}
}
