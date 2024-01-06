import UIKit

public protocol Coordinator: AnyObject {
  func addChild(_ child: Coordinator)
  func removeChild(_ child: Coordinator)
  func start()
}

public class RouterCoordinator<CoordinatorRouter: Router>: Coordinator {
  let router: CoordinatorRouter
  private var children = [Coordinator]()
  
  public init(router: CoordinatorRouter) {
    self.router = router
  }
  
  deinit {
    print("\(String(describing: self)) deinit")
  }
  
  public func addChild(_ child: Coordinator) {
    guard !children.contains(where: { $0 === child }) else { return }
    children.append(child)
  }
  
  public func removeChild(_ child: Coordinator) {
    guard !children.isEmpty else { return }
    children.removeAll(where: { $0 === child })
  }
  
  public func start() {}
}
