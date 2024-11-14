import UIKit

@MainActor
public protocol Coordinator: AnyObject {
  func addChild(_ child: Coordinator)
  func removeChild(_ child: Coordinator?)
  func start()
  func start(deeplink: CoordinatorDeeplink?)
  func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool
  func didMoveTo(toParent parent: Coordinator?)
}

open class RouterCoordinator<CoordinatorRouter: Router>: Coordinator {
  public let router: CoordinatorRouter
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
    child.didMoveTo(toParent: self)
  }
  
  public func removeChild(_ child: Coordinator?) {
    guard !children.isEmpty, let child else { return }
    children.removeAll(where: { $0 === child })
    child.didMoveTo(toParent: nil)
  }
  
  open func start() {}
  open func start(deeplink: CoordinatorDeeplink? = nil) {}
  open func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool { return false }
  open func didMoveTo(toParent parent: Coordinator?) {}
}
