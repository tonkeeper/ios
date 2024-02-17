import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore

public final class WalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
    router.rootViewController.tabBarItem.title = "Wallet"
    router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.wallet
  }
  
  public override func start() {
    openWalletContainer()
  }
}

private extension WalletCoordinator {
  func openWalletContainer() {
    let module = WalletContainerAssembly.module(
      childModuleProvider: self, 
      walletMainController: keeperCoreMainAssembly.walletMainController()
    )
    
    module.output.didTapWalletButton = { [weak self] in
      self?.openWalletPicker()
    }
    
    module.output.didTapSettingsButton = { [weak self] in
      self?.openSettings()
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openWalletPicker() {
    let module = WalletsListAssembly.module(
      walletListController: keeperCoreMainAssembly.walletListController()
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    module.output.didTapAddWalletButton = { [weak self, unowned bottomSheetViewController] in
      self?.openAddWallet(router: ViewControllerRouter(rootViewController: bottomSheetViewController)) {
        bottomSheetViewController.dismiss()
      }
    }
    
    module.output.didSelectWallet = { [weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss()
    }
    
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func openAddWallet(router: ViewControllerRouter, onAddWallets: @escaping () -> Void) {
    let module = AddWalletModule(dependencies: AddWalletModule.Dependencies(
      walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly)
    )
    
    let coordinator = module.createAddWalletCoordinator(router: router)
    coordinator.didAddWallets = {
      onAddWallets()
    }
    
    addChild(coordinator)
    coordinator.start()
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
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openTonDetails() {
    let historyListModule = HistoryModule(
      dependencies: HistoryModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createTonHistoryListModule()
    
    historyListModule.output.didSelectEvent = { [weak self] event in
      self?.openHistoryEventDetails(event: event)
    }
    
    let module = TokenDetailsAssembly.module(
      tokenDetailsListContentViewController: historyListModule.view,
      tokenDetailsController: keeperCoreMainAssembly.tonTokenDetailsController(),
      chartViewControllerProvider: { [keeperCoreMainAssembly] in
        TonChartAssembly.module(chartController: keeperCoreMainAssembly.chartController()).view
      },
      hasAbout: true
    )
    
    module.output.didTapReceive = { [weak self] token in
      self?.openReceive(token: token)
    }
    
    router.push(viewController: module.view)
  }
  
  func openJettonDetails(jettonInfo: JettonInfo) {
    let historyListModule = HistoryModule(
      dependencies: HistoryModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createJettonHistoryListModule(jettonInfo: jettonInfo)
    
    historyListModule.output.didSelectEvent = { [weak self] event in
      self?.openHistoryEventDetails(event: event)
    }
    
    let module = TokenDetailsAssembly.module(
      tokenDetailsListContentViewController: historyListModule.view,
      tokenDetailsController: keeperCoreMainAssembly.jettonTokenDetailsController(jettonInfo: jettonInfo),
      chartViewControllerProvider: nil,
      hasAbout: false
    )
    
    module.output.didTapReceive = { [weak self] token in
      self?.openReceive(token: token)
    }
    
    router.push(viewController: module.view)
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
    navigationController.configureTransparentAppearance()
    
    
    router.present(navigationController)
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
}

extension WalletCoordinator: WalletContainerViewModelChildModuleProvider {
  func getWalletBalanceModuleView(wallet: Wallet) -> UIViewController {
    let walletBalanceController = keeperCoreMainAssembly.walletBalanceController(wallet: wallet)
    let module = WalletBalanceAssembly.module(walletBalanceController: walletBalanceController)
    
    module.output.didSelectTon = { [weak self] in
      self?.openTonDetails()
    }
    
    module.output.didSelectJetton = { [weak self] jettonInfo in
      self?.openJettonDetails(jettonInfo: jettonInfo)
    }
    
    module.output.didTapReceive = { [weak self] in
      self?.openReceive(token: .ton)
    }
    
    module.output.didTapBackup = { [weak self] in
      self?.openBackup(wallet: wallet)
    }
    
    return module.view
  }
}
