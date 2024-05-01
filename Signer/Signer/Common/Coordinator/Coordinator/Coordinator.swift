import UIKit

protocol Coordinator: AnyObject {
  func addChild(_ child: Coordinator)
  func removeChild(_ child: Coordinator)
  func start()
}

class RouterCoordinator<CoordinatorRouter: Router>: Coordinator {
  let router: CoordinatorRouter
  private var children = [Coordinator]()
  
  init(router: CoordinatorRouter) {
    self.router = router
  }
  
  deinit {
    print("\(String(describing: self)) deinit")
  }
  
  func addChild(_ child: Coordinator) {
    guard !children.contains(where: { $0 === child }) else { return }
    children.append(child)
  }
  
  func removeChild(_ child: Coordinator) {
    guard !children.isEmpty else { return }
    children.removeAll(where: { $0 === child })
  }
  
  func start() {}
}
