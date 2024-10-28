import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore
import TonSwift

final class StakingConfirmationCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  var didClose: (() -> Void)?
  
  private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?
  
  private let wallet: Wallet
  private let item: StakingConfirmationItem
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(wallet: Wallet,
       item: StakingConfirmationItem,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter) {
    self.wallet = wallet
    self.item = item
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    
    super.init(router: router)
  }
  
  override func start(deeplink: (any CoordinatorDeeplink)? = nil) {
    openConfirmation(wallet: wallet, item: item)
  }
  
  func openConfirmation(wallet: Wallet, item: StakingConfirmationItem) {
    let transactionConfirmationController: TransactionConfirmationController
    switch item.operation {
    case .deposit(let stackingPoolInfo):
      transactionConfirmationController = keeperCoreMainAssembly.stakingDepositTransactionConfirmationController(
        wallet: wallet,
        stakingPool: stackingPoolInfo,
        amount: item.amount,
        isMax: item.isMax,
        isCollect: false
      )
    case .withdraw(let stackingPoolInfo):
      transactionConfirmationController = keeperCoreMainAssembly.stakingWithdrawTransactionConfirmationController(
        wallet: wallet,
        stakingPool: stackingPoolInfo,
        amount: item.amount,
        isMax: item.isMax,
        isCollect: false
      )
    }
    let module = TransactionConfirmationAssembly.module(
      transactionConfirmationController: transactionConfirmationController,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    module.output.didRequireSign = { [weak self, keeperCoreMainAssembly, coreAssembly] walletTransfer, wallet in
      guard let self = self else { return nil }
      let coordinator = WalletTransferSignCoordinator(
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
    
    module.output.didClose = { [weak self] in
      self?.didClose?()
    }
    
    router.push(viewController: module.view, onPopClosures: { [weak self] in
      self?.didFinish?()
    })
  }
}
