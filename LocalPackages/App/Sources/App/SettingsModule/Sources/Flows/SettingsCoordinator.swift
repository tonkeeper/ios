import UIKit
import TKCoordinator
import TKUIKit

public final class SettingsCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didFinish: (() -> Void)?
  
  public override func start() {
    openSettingsRoot()
  }
}

private extension SettingsCoordinator {
  func openSettingsRoot() {
    let module = SettingsRootAssembly.module()

    router.push(viewController: module.viewController,
                onPopClosures: { [weak self] in
      self?.didFinish?()
    })
  }
}
