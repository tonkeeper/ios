import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore
import TonSwift

final class StakingStakeCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
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
    openStakingDepositInput()
  }
  
  func openStakingDepositInput() {
    let stakingDepositInputAPY = StakingDepositInputAPYAssembly.module(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    let configurator = StakingDepositInputModelConfigurator(
      wallet: wallet,
      balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore
    )
    
    let module = StakingInputAssembly.module(
      model: StakingInputModelImplementation(
        wallet: wallet,
        stakingPoolInfo: stakingPoolInfo,
        detailsInput: stakingDepositInputAPY.input,
        configurator: configurator,
        stakingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
        tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
        currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore
      ),
      detailsViewController: stakingDepositInputAPY.view,
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
    case .deposit(let stackingPoolInfo):
      controller = keeperCoreMainAssembly.stakingDepositConfirmationController(
        wallet: wallet,
        stakingPool: stackingPoolInfo,
        amount: item.amount,
        isMax: item.isMax
      )
    case .withdraw(let stackingPoolInfo):
      return
    }
    
    let module = StakingConfirmationAssembly.module(stakingConfirmationController: controller)
    
    module.output.didSendTransaction = { [weak self] in
      NotificationCenter.default.post(Notification(name: Notification.Name("DID SEND TRANSACTION")))
      self?.router.dismiss(completion: {
        self?.didFinish?()
      })
    }
    
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
