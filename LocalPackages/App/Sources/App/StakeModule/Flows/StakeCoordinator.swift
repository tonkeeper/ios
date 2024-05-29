import UIKit
import TKScreenKit
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
    
    module.output.didTapStakePool = { [weak self, weak input = module.input] selectedStakePool in
      self?.openStakeOptions(selectedStakePool: selectedStakePool, didChoosePool: input?.didChoosePool)
    }
    
    module.output.didTapContinue = {
      print("didTapContinue")
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openStakeOptions(selectedStakePool: StakePool, didChoosePool: ((StakePool) -> Void)?) {
    let module = StakeOptionsAssembly.module(
      stakeOptionsController: keeperCoreMainAssembly.stakeOptionsController(),
      selectedStakePool: selectedStakePool
    )
    
    module.view.setupBackButton()
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didTapOtherPoolCell = { [weak self] poolTitle, poolItems in
      self?.openPoolList(poolTitle: poolTitle, poolItems: poolItems)
    }
    
    module.output.onOpenPoolDetails = { [weak self] pool in
      self?.openPoolDetails(pool: pool, didChoosePool: didChoosePool)
    }
    
    router.push(viewController: module.view, animated: true)
  }
  
  func openPoolList(poolTitle: String, poolItems: [SelectionCollectionViewCell.Configuration]) {
    let poolListView = StakeOptionsPoolListViewController(
      title: poolTitle,
      poolItems: poolItems
    )
    
    poolListView.setupBackButton()
    
    poolListView.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    router.push(viewController: poolListView, animated: true)
  }
  
  func openPoolDetails(pool: StakePool, didChoosePool: ((StakePool) -> Void)?) {
    let module = StakePoolDetailsAssembly.module(
      stakePoolDetailsController: keeperCoreMainAssembly.stakePoolDetailsController(),
      stakePool: pool
    )
    
    module.view.setupBackButton()
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didTapLink = { [weak self, weak view = module.view] titledUrl in
      guard let view else { return }
      self?.openBridgeWebView(titledUrl: titledUrl, fromViewController: view)
    }
    
    module.output.didChoosePool = { [weak self] newPool in
      didChoosePool?(newPool)
      self?.router.popToRoot(animated: true)
    }
    
    router.push(viewController: module.view, animated: true)
  }
  
  func openBridgeWebView(titledUrl: TitledURL, fromViewController: UIViewController) {
    let bridgeWebViewController = TKBridgeWebViewController(
      initialURL: titledUrl.url,
      initialTitle: titledUrl.title,
      jsInjection: nil
    )
    bridgeWebViewController.modalPresentationStyle = .fullScreen
    fromViewController.present(bridgeWebViewController, animated: true)
  }
}
