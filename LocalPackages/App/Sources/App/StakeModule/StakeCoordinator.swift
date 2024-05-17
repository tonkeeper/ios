import UIKit
import TKUIKit
import TKScreenKit
import TKCoordinator
import TKCore
import KeeperCore

public final class StakeCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  var didUpdateSendModel: ((SendModel) -> Void)?
  
  private let wallet: Wallet
  private let walletsStore: WalletsStore
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       wallet: Wallet
  ) {
    self.wallet = wallet
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    self.walletsStore = keeperCoreMainAssembly.walletAssembly.walletStore
    super.init(router: router)
  }
  
  public override func start() {
    openStake()
  }
}

private extension StakeCoordinator {
  
  func openStake() {
    
    let module = StakeAssembly.module(
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      walletsStore: walletsStore
    )
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didContinueStake = { [weak self] in
      self?.openStakeNextScreen()
    }
    
    router.push(viewController: module.view)
  }
  
  func openStakeNextScreen() {
    let module = StakeConfirmationAssembly.module()
    
    module.output.didSendTransaction = { [weak self] in
      self?.router.dismiss()
    }
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
  
}
