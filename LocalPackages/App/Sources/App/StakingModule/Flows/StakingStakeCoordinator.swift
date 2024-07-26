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
    
    let module = StakingInputAssembly.module(
      model: StakingDepositInputModel(
        wallet: wallet,
        stakingPoolInfo: stakingPoolInfo,
        detailsInput: stakingDepositInputAPY.input,
        balanceStore: keeperCoreMainAssembly.mainStoresAssembly.convertedBalanceStore,
        stakingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
        tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStoreV2,
        currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStoreV2
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
//  func openWithdrawEditAmount(stakingPool: StakingPool) {
//    let editAmountModule = StakingWithdrawEditAmountAssembly.module(stakingPool: stakingPool, keeperCoreMainAssembly: keeperCoreMainAssembly)
//
//    editAmountModule.view.setupRightCloseButton { [weak self] in
//      self?.didFinish?()
//    }
//
//    editAmountModule.output.didTapContinue = { [weak self] confirmItem in
//      let confirmOutput = self?.openConfirm(item: confirmItem)
//      confirmOutput?.didRequireConfirmation = { [weak self] in
//        guard let self else { return false }
//        return await self.openPasscode(fromViewController: self.router.rootViewController)
//      }
//
//      confirmOutput?.didFinish = { [weak self] in
//        self?.didFinish?()
//      }
//
//      confirmOutput?.didReceiveInsufficientFunds = { [weak self] fundsModel in
//        guard let self else { return }
//        let insufficientFundsModule = StakingInsufficientFundsAssembly.module(
//          fundsModel: fundsModel,
//          keeperCoreMainAssembly: keeperCoreMainAssembly
//        )
//
//        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: insufficientFundsModule.view)
//        bottomSheetViewController.present(fromViewController: router.rootViewController)
//
//        insufficientFundsModule.output.didTapBuy = { [weak self] wallet in
//          self?.router.dismiss(animated: false) {
//            self?.openBuy(wallet: wallet)
//          }
//        }
//      }
//    }
//
//    router.push(viewController: editAmountModule.view, animated: false)
//  }
//
//  func openDepositEditAmount(stakingPool: StakingPool) {
//    let editAmountModule = StakingDepositEditAmountAssembly.module(stakingPool: stakingPool, keeperCoreMainAssembly: keeperCoreMainAssembly)
//
//    editAmountModule.view.setupButton(icon: UIImage.TKUIKit.Icons.Size16.infoCircle, position: .left) { [weak self] in
//      guard
//        let self,
//        let url = URL(string: "https://telegra.ph/Guide-How-to-Stake-TON-Within-Tonkeeper-Wallet-05-23")
//      else { return }
//      // вынести
//      self.coreAssembly.urlOpener().open(url: url)
//    }
//
//    editAmountModule.view.setupRightCloseButton { [weak self] in
//      self?.didFinish?()
//    }
//
//    editAmountModule.output.didTapPoolPicker = { [weak self] listModel, selectedPoolAddress in
//      let poolTypeOutput = self?.openOptionsList(listModel: listModel, selectedPoolAddress: selectedPoolAddress)
//
//      poolTypeOutput?.didChooseStakingPool = { stakingPool in
//        editAmountModule.input.setStakingPool(stakingPool)
//        self?.router.popTo(viewController: editAmountModule.view, animated: true, completion: nil)
//      }
//
//      poolTypeOutput?.didTapOptionDetails = { pool in
//        let detailsOutput = self?.openOptionDetails(stakingPool: pool)
//
//        detailsOutput?.didChooseStakingPool = { pool in
//          editAmountModule.input.setStakingPool(pool)
//          self?.router.popTo(viewController: editAmountModule.view, animated: true, completion: nil)
//        }
//      }
//
//      poolTypeOutput?.didTapPoolImplementation = { model, selectedPoolAddress in
//        let exactPoolOutput = self?.openOptionsList(listModel: model, selectedPoolAddress: selectedPoolAddress)
//        exactPoolOutput?.didTapOptionDetails = { pool in
//          let detailsOutput = self?.openOptionDetails(stakingPool: pool)
//
//          detailsOutput?.didChooseStakingPool = { pool in
//            editAmountModule.input.setStakingPool(pool)
//            self?.router.popTo(viewController: editAmountModule.view, animated: true, completion: nil)
//          }
//        }
//
//        exactPoolOutput?.didChooseStakingPool = { [weak self] stakingPool in
//          editAmountModule.input.setStakingPool(stakingPool)
//          self?.router.popTo(viewController: editAmountModule.view, animated: true, completion: nil)
//        }
//      }
//    }
//
//    editAmountModule.output.didTapContinue = { [weak self] confirmationItem in
//      let confirmOutput = self?.openConfirm(item: confirmationItem)
//      confirmOutput?.didRequireConfirmation = { [weak self] in
//        guard let self else { return false }
//        return await self.openPasscode(fromViewController: self.router.rootViewController)
//      }
//
//      confirmOutput?.didFinish = { [weak self] in
//        self?.didFinish?()
//      }
//
//      confirmOutput?.didReceiveInsufficientFunds = { [weak self] fundsModel in
//        guard let self else { return }
//        let insufficientFundsModule = StakingInsufficientFundsAssembly.module(
//          fundsModel: fundsModel,
//          keeperCoreMainAssembly: keeperCoreMainAssembly
//        )
//
//        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: insufficientFundsModule.view)
//        bottomSheetViewController.present(fromViewController: router.rootViewController)
//
//        insufficientFundsModule.output.didTapBuy = { [weak self] wallet in
//          self?.router.dismiss(animated: false) {
//            self?.openBuy(wallet: wallet)
//          }
//        }
//      }
//    }
//
//    editAmountModule.output.didTapBuy = { [weak self] wallet  in
//      self?.openBuy(wallet: wallet)
//    }
//
//    router.push(viewController: editAmountModule.view, animated: false)
//  }
//}
//
//// MARK: - Private methods
//
//private extension StakingCoordinator {
//  func openConfirm(item: StakingConfirmationItem) -> StakingConfirmationModuleOutput {
//    let module = StakingConfirmationAssembly.module(
//      stakeConfirmationItem: item,
//      keeperCoreMainAssembly: keeperCoreMainAssembly
//    )
//
//    module.view.setupRightCloseButton { [weak self] in
//      self?.didFinish?()
//    }
//
//    router.push(viewController: module.view)
//
//    return module.output
//  }
//
//  func openOptionsList(
//    listModel: StakingOptionsListModel,
//    selectedPoolAddress: Address?
//  ) -> StakingOptionsListModuleOutput {
//    let module = StakingOptionsListAssembly.module(
//      keeperCoreMainAssembly: keeperCoreMainAssembly,
//      listModel: listModel,
//      selectedPoolAddress: selectedPoolAddress
//    )
//
//    module.view.setupRightCloseButton { [weak self] in
//      self?.didFinish?()
//    }
//
//    router.push(viewController: module.view)
//
//    return module.output
//  }
//
//  func openOptionDetails(stakingPool: StakingPool) -> StakingOptionDetailsModuleOutput {
//    let module = StakingOptionDetailsAssembly.module(
//      stakingPool: stakingPool,
//      keeperCoreMainAssembly: keeperCoreMainAssembly,
//      urlOpener: coreAssembly.urlOpener()
//    )
//
//    module.view.setupRightCloseButton { [weak self] in
//      self?.didFinish?()
//    }
//
//    router.push(viewController: module.view)
//
//    return module.output
//  }
//
//  func openPasscode(fromViewController: UIViewController) async -> Bool {
//    return await Task<Bool, Never> { @MainActor in
//      return await withCheckedContinuation { [weak self, keeperCoreMainAssembly] (continuation: CheckedContinuation<Bool, Never>) in
//        guard let self = self else { return }
//        let coordinator = PasscodeModule(
//          dependencies: PasscodeModule.Dependencies(
//            passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
//          )
//        ).passcodeConfirmationCoordinator()
//
//        coordinator.didCancel = { [weak self, weak coordinator] in
//          continuation.resume(returning: false)
//          coordinator?.router.dismiss(completion: {
//            guard let coordinator else { return }
//            self?.removeChild(coordinator)
//          })
//        }
//
//        coordinator.didConfirm = { [weak self, weak coordinator] in
//          continuation.resume(returning: true)
//          coordinator?.router.dismiss(completion: {
//            guard let coordinator else { return }
//            self?.removeChild(coordinator)
//          })
//        }
//
//        self.addChild(coordinator)
//        coordinator.start()
//
//        fromViewController.present(coordinator.router.rootViewController, animated: true)
//      }
//    }.value
//  }
//
//  func openBuy(wallet: Wallet) {
//    let coordinator = BuyCoordinator(
//      wallet: wallet,
//      keeperCoreMainAssembly: keeperCoreMainAssembly,
//      coreAssembly: coreAssembly,
//      router: ViewControllerRouter(rootViewController: self.router.rootViewController)
//    )
//
//    addChild(coordinator)
//    coordinator.start()
//  }
//}
