import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore
import TonSwift

final class StakingUnstakeCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  
  private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?
  
  private let wallet: Wallet
  private let stakingPoolInfo: StackingPoolInfo
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(wallet: Wallet,
       stakingPoolInfo: StackingPoolInfo,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter) {
    self.wallet = wallet
    self.stakingPoolInfo = stakingPoolInfo
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    
    super.init(router: router)
  }
  
  override func start(deeplink: (any CoordinatorDeeplink)? = nil) {
    openStakingWithdrawInput()
  }
  
  func openStakingWithdrawInput() {
    let stakingWithdrawEstimateViewController = StakingWithdrawEstimateViewController(
      wallet: wallet,
      stakingPoolInfo: stakingPoolInfo
    )
    
    let configurator = StakingWithdrawInputModelConfigurator(
      wallet: wallet,
      poolInfo: stakingPoolInfo,
      balanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore
    )
    
    let module = StakingInputAssembly.module(
      model: StakingInputModelImplementation(
        wallet: wallet,
        stakingPoolInfo: stakingPoolInfo,
        detailsInput: stakingWithdrawEstimateViewController,
        configurator: configurator,
        stakingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
        tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
        currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore
      ),
      detailsViewController: stakingWithdrawEstimateViewController,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didConfirm = { [weak self] item in
      guard let self else { return }
      self.openConfirmation(wallet: self.wallet, item: item)
    }
    
    router.push(viewController: module.view)
  }
  
  func openConfirmation(wallet: Wallet, item: StakingConfirmationItem) {
    let controller: StakeConfirmationController
    switch item.operation {
    case .deposit:
      return
    case .withdraw(let stackingPoolInfo):
      controller = keeperCoreMainAssembly.stakingWithdrawConfirmationController(
        wallet: wallet,
        stakingPool: stackingPoolInfo,
        amount: item.amount,
        isMax: item.isMax,
        isCollect: false
      )
    }
    
    let module = StakingConfirmationAssembly.module(wallet: wallet,
                                                    stakingConfirmationController: controller)
    
    module.output.didRequireSign = { [weak self, keeperCoreMainAssembly, coreAssembly] walletTransfer, wallet in
      guard let self = self else { return nil }
      let coordinator = await WalletTransferSignCoordinator(
        router: ViewControllerRouter(rootViewController: router.rootViewController),
        wallet: wallet,
        transferMessageBuilder: walletTransfer,
        keeperCoreMainAssembly: keeperCoreMainAssembly,
        coreAssembly: coreAssembly)
      
      self.walletTransferSignCoordinator = coordinator
      
      let result = await coordinator.handleSign(parentCoordinator: self)
    
      switch result {
      case .signed(let data):
        return data
      case .cancel:
        return nil
      case .failed(let error):
        throw error
      }
    }
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
}
