//
//  Coordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import Foundation

protocol CoordinatorProtocol: AnyObject {
  var initialPresentable: Presentable? { get }
  func addChild(_ child: CoordinatorProtocol)
  func removeChild(_ child: CoordinatorProtocol)
  func start()
}

class Coordinator<Router: RouterProtocol>: CoordinatorProtocol {
  
  var initialPresentable: Presentable?
  
  let router: Router
  
  private var children = [CoordinatorProtocol]()
  
  init(router: Router) {
    self.router = router
  }
  
  deinit {
    print("👄 \(String(describing: self)) deinit")
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
  func start(deeplink: Deeplink?) {}
  
  func handleDeeplink(_ deeplink: Deeplink) {}
}
