import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore
import TonSwift
import BigInt

final class StakingUnstakeCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  var didClose: (() -> Void)?
  
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
    if (stakingPoolInfo.implementation.type == .tf) {
      var withdrawAmount: BigUInt {
        BigUInt(keeperCoreMainAssembly.storesAssembly.processedBalanceStore.state[wallet]?.balance.stakingItems
          .first(where: { $0.poolInfo?.address == stakingPoolInfo.address })?
          .info.amount ?? 0)
      }
      
      openConfirmation(wallet: wallet, item: .init(operation: .withdraw(stakingPoolInfo), amount: withdrawAmount))
    }
    else {
      openStakingWithdrawInput()
    }
  }
  
  func openStakingWithdrawInput() {
    let stakingWithdrawEstimateViewController = StakingWithdrawEstimateViewController(
      wallet: wallet,
      stakingPoolInfo: stakingPoolInfo
    )

    let configurator = WithdrawStakingInputViewModelConfiguration(
      wallet: wallet,
      stakingPool: stakingPoolInfo,
      balanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore
    )

    let module = StakingInputAssembly.module(
      configuration: configurator,
      detailsViewController: stakingWithdrawEstimateViewController,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didConfirm = { [weak self] item in
      guard let self else { return }
      Task {
        await MainActor.run {
          self.openConfirmation(wallet: self.wallet, item: item)
        }
      }
    }
    
    module.output.didClose = { [weak self] in
      self?.didClose?()
    }
    
    router.push(viewController: module.view)
  }
  
  @MainActor func openConfirmation(wallet: Wallet, item: StakingConfirmationItem) {
    let coordinator = StakingConfirmationCoordinator(
      wallet: wallet,
      item: item,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly,
      router: router
    )
    
    coordinator.didFinish = { [weak self, weak coordinator] in
      self?.removeChild(coordinator)
    }
    
    coordinator.didClose = { [weak self, weak coordinator] in
      self?.didClose?()
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start(deeplink: nil)
  }
}
