import UIKit
import TKCoordinator
import TKCore
import KeeperCore

public final class StakeCoordinator: RouterCoordinator<NavigationControllerRouter> {
    
  var didFinish: (() -> Void)?
  
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter) {
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  public override func start() {
    openStake()
  }
}

private extension StakeCoordinator {
  func openStake() {
    let module = StakeAssembly.module(
      stakeController: keeperCoreMainAssembly.stakeController()
    )
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didTapContinue = {
      print("didTapContinue")
    }
    
    router.push(viewController: module.view, animated: false)
  }
}
