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
    
    module.output.didTapStakePool = { [weak self, weak input = module.input] in
      self?.openStakeOptions(didSelectPool: input?.didSelectPool)
    }
    
    module.output.didTapContinue = {
      print("didTapContinue")
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openStakeOptions(didSelectPool: ((StakePool) -> Void)?) {
    let module = StakeOptionsAssembly.module(
      stakeOptionsController: keeperCoreMainAssembly.stakeOptionsController()
    )
    
    module.view.setupBackButton()
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didSelectOtherPool = { [weak self] poolTitle, seletedId, poolItems in
      self?.openPoolList(poolTitle: poolTitle, selectedId: seletedId, poolItems: poolItems)
    }
    
    module.output.didSelectNewPool = { pool in
      didSelectPool?(pool)
    }
    
    router.push(viewController: module.view, animated: true)
  }
  
  func openPoolList(poolTitle: String, selectedId: String, poolItems: [SelectionCollectionViewCell.Configuration]) {
    let poolListView = StakeOptionsPoolListViewController(
      title: poolTitle,
      selectedId: selectedId,
      poolItems: poolItems
    )
    
    poolListView.setupBackButton()
    
    poolListView.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    router.push(viewController: poolListView, animated: true)
  }
}
