import UIKit
import TKCoordinator
import TKCore
import KeeperCore

final class SwapTokenCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didFinish: (() -> Void)?
  
  private var externalSignHandler: ((Data) async -> Void)?
  
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
  }

  public override func start() {
    openSwap()
  }
}

private extension SwapTokenCoordinator {
  func openSwap() {
    let module = SwapAssembly.module(
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )

    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }

    router.push(viewController: module.view, animated: false)
  }
}
