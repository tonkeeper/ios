import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize

public final class WalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didTapScan: (() -> Void)?
  var didLogout: (() -> Void)?
  var didTapWalletButton: (() -> Void)?
  var didTapSend: ((Token) -> Void)?
  var didTapSwap: (() -> Void)?
  
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
      router.rootViewController.tabBarItem.title = TKLocales.Tabs.wallet
    router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.wallet
  }
  
  public override func start() {
    openWalletContainer()
  }
}

private extension WalletCoordinator {
  func openWalletContainer() {
    let module = WalletContainerAssembly.module(
      walletBalanceModule: createWalletBalanceModule(),
      walletMainController: keeperCoreMainAssembly.walletMainController()
    )
    
    module.output.didTapWalletButton = { [weak self] in
      self?.didTapWalletButton?()
    }
    
    module.output.didTapSettingsButton = { [weak self] in
      self?.openSettings()
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openSettings() {
    let module = SettingsModule(
      dependencies: SettingsModule.Dependencies(
        keeperCoreMainAssembly: keeperCoreMainAssembly,
        coreAssembly: coreAssembly
      )
    )
    
    let coordinator = module.createSettingsCoordinator(router: router)
    coordinator.didFinish = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    }
    coordinator.didLogout = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      self?.didLogout?()
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openTonDetails(wallet: Wallet) {
    let historyListModule = HistoryModule(
      dependencies: HistoryModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createTonHistoryListModule(wallet: wallet)
    
    historyListModule.output.didSelectEvent = { [weak self] event in
      self?.openHistoryEventDetails(event: event)
    }
    
    let module = TokenDetailsAssembly.module(
      tokenDetailsListContentViewController: historyListModule.view,
      tokenDetailsController: keeperCoreMainAssembly.tonTokenDetailsController(),
      chartViewControllerProvider: { [keeperCoreMainAssembly, coreAssembly] in
        ChartAssembly.module(token: .ton,
                             coreAssembly: coreAssembly,
                             keeperCoreMainAssembly: keeperCoreMainAssembly).view
      },
      hasAbout: true
    )
    
    module.output.didTapReceive = { [weak self] token in
      self?.openReceive(token: token)
    }
    
    module.output.didTapSend = { [weak self] token in
      self?.openSend(token: token)
    }
    
    module.output.didTapBuyOrSell = { [weak self] in
      self?.openBuy(wallet: wallet)
    }
    
    router.push(viewController: module.view)
  }
  
  func openJettonDetails(jettonItem: JettonItem, wallet: Wallet, hasPrice: Bool, stakingPool: StakingPool?) {
    let historyListModule = HistoryModule(
      dependencies: HistoryModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createJettonHistoryListModule(jettonItem: jettonItem, wallet: wallet)
    
    historyListModule.output.didSelectEvent = { [weak self] event in
      self?.openHistoryEventDetails(event: event)
    }
    
    let module = TokenDetailsAssembly.module(
      tokenDetailsListContentViewController: historyListModule.view,
      tokenDetailsController: keeperCoreMainAssembly.jettonTokenDetailsController(jettonItem: jettonItem, stakingPool: stakingPool),
      chartViewControllerProvider: { [keeperCoreMainAssembly, coreAssembly] in
        if let stakingPool {
          return ChartAssembly.module(
            jetton: jettonItem,
            stakingPool: stakingPool,
            token: .ton,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
          ).view
        }
        
        if !hasPrice {
          return nil
        }
        
        return ChartAssembly.module(token: .jetton(jettonItem),
                                    coreAssembly: coreAssembly,
                                    keeperCoreMainAssembly: keeperCoreMainAssembly).view
      },
      hasAbout: false
    )
    
    module.output.didTapReceive = { [weak self] token in
      self?.openReceive(token: token)
    }
    
    module.output.didTapSend = { [weak self] token in
      self?.openSend(token: token)
    }
    
    module.output.didTapWithdraw = { [weak self] withdrawModel in
      self?.openWithdraw(model: withdrawModel)
    }
    
    module.output.didTapDeposit = { [weak self] depositModel in
      self?.openDeposit(model: depositModel)
    }
    
    router.push(viewController: module.view)
  }
  
  func openSend(token: Token) {
    didTapSend?(token)
  }
  
  func openWithdraw(model: WithdrawModel) {
    let navigationController = TKNavigationController()
    navigationController.configureDefaultAppearance()
    let router = NavigationControllerRouter(rootViewController: navigationController)
    
    let module = StakingModule(dependencies:
        .init(
          keeperCoreMainAssembly: keeperCoreMainAssembly,
          coreAssembly: coreAssembly)
    )
    
    let coordinator = module.createStakingCoordinator(router: router)
    coordinator.didFinish = { [weak self, weak coordinator, weak navigationController] in
      navigationController?.dismiss(animated: true)
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.openWithdrawEditAmount(withdrawModel: model)
    
    self.router.present(navigationController)
  }
  
  func openDeposit(model: DepositModel) {
    let navigationController = TKNavigationController()
    navigationController.configureDefaultAppearance()
    let router = NavigationControllerRouter(rootViewController: navigationController)
    
    let module = StakingModule(dependencies:
        .init(
          keeperCoreMainAssembly: keeperCoreMainAssembly,
          coreAssembly: coreAssembly)
    )
    
    let coordinator = module.createStakingCoordinator(router: router)
    coordinator.didFinish = { [weak self, weak coordinator, weak navigationController] in
      navigationController?.dismiss(animated: true)
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.openDepositEditAmount(depositeModel: model)
    
    self.router.present(navigationController)
  }
  
  func openReceive(token: Token) {
    let module = ReceiveModule(
      dependencies: ReceiveModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).receiveModule(token: token)
    
    module.view.setupSwipeDownButton()
    
    let navigationController = TKNavigationController(rootViewController: module.view)
    navigationController.configureDefaultAppearance()
    
    router.present(navigationController)
  }
  
  func openBuy(wallet: Wallet) {
    let coordinator = BuyCoordinator(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly,
      router: ViewControllerRouter(rootViewController: self.router.rootViewController)
    )
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openHistoryEventDetails(event: AccountEventDetailsEvent) {
    let module = HistoryEventDetailsAssembly.module(
      historyEventDetailsController: keeperCoreMainAssembly.historyEventDetailsController(event: event),
      urlOpener: coreAssembly.urlOpener()
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func openBackup(wallet: Wallet) {
    let coordinator = BackupModule(
      dependencies: BackupModule.Dependencies(
        keeperCoreMainAssembly: keeperCoreMainAssembly,
        coreAssembly: coreAssembly
      )
    ).createBackupCoordinator(
      router: router,
      wallet: wallet
    )
    
    coordinator.didFinish = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openConfirmation() async -> Bool {
    return await Task<Bool, Never> { @MainActor in
      return await withCheckedContinuation { [weak self, keeperCoreMainAssembly] (continuation: CheckedContinuation<Bool, Never>) in
        guard let self = self else { return }
        let coordinator = PasscodeModule(
          dependencies: PasscodeModule.Dependencies(
            passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
          )
        ).passcodeConfirmationCoordinator()
        
        coordinator.didCancel = { [weak self, weak coordinator] in
          continuation.resume(returning: false)
          coordinator?.router.dismiss(completion: {
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
        
        coordinator.didConfirm = { [weak self, weak coordinator] in
          continuation.resume(returning: true)
          coordinator?.router.dismiss(completion: {
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
        
        self.addChild(coordinator)
        coordinator.start()
        
        self.router.present(coordinator.router.rootViewController)
      }
    }.value
  }

  func createWalletBalanceModule() -> WalletBalanceModule {
    let walletBalanceController = keeperCoreMainAssembly.walletBalanceController()
    let module = WalletBalanceAssembly.module(walletBalanceController: walletBalanceController)
    
    module.output.didSelectTon = { [weak self] wallet in
      self?.openTonDetails(wallet: wallet)
    }
    
    module.output.didSelectJetton = { [weak self] wallet, jettonItem, hasPrice in
      self?.openJettonDetails(jettonItem: jettonItem, wallet: wallet, hasPrice: hasPrice, stakingPool: nil)
    }
    
    module.output.didSelectLPJetton = { [weak self] wallet, jetton, stakingPool in
      self?.openJettonDetails(jettonItem: jetton, wallet: wallet, hasPrice: true, stakingPool: stakingPool)
    }
    
    module.output.didTapSend = { [weak self] in
      self?.openSend(token: .ton)
    }
    
    module.output.didTapReceive = { [weak self] in
      self?.openReceive(token: .ton)
    }
    
    module.output.didTapScan = { [weak self] in
      self?.didTapScan?()
    }
    
    module.output.didTapBuy = { [weak self] wallet in
      self?.openBuy(wallet: wallet)
    }
    
    module.output.didTapSwap = { [weak self] in
      self?.didTapSwap?()
    }
    
    module.output.didTapBackup = { [weak self] wallet in
      self?.openBackup(wallet: wallet)
    }
    
    module.output.didTapStake = { [weak self] model in
      self?.openDeposit(model: model)
    }
    
    module.output.didRequireConfirmation = { [weak self] in
      return (await self?.openConfirmation()) ?? false
    }
    
    return module
  }
}
