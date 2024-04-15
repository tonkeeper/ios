import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore

public final class WalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didTapScan: (() -> Void)?
  var didLogout: (() -> Void)?
  
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
      walletListController: keeperCoreMainAssembly.walletStoreWalletListController()
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    module.output.didTapAddWalletButton = { [weak self, unowned bottomSheetViewController] in
      bottomSheetViewController.dismiss {
        guard let self else { return }
        self.openAddWallet(router: ViewControllerRouter(rootViewController: self.router.rootViewController))
      }
    }
    
    module.output.didTapEditWallet = { [weak self, unowned bottomSheetViewController] in
      self?.openEditWallet(wallet: $0, fromViewController: bottomSheetViewController)
    }
    
    module.output.didSelectWallet = { [weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss()
    }
    
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func openAddWallet(router: ViewControllerRouter) {
    let module = AddWalletModule(dependencies: AddWalletModule.Dependencies(
      walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly)
    )
    
    let coordinator = module.createAddWalletCoordinator(router: router)
    coordinator.didAddWallets = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
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
      chartViewControllerProvider: { [keeperCoreMainAssembly] in
        TonChartAssembly.module(chartController: keeperCoreMainAssembly.chartController()).view
      },
      hasAbout: true
    )
    
    module.output.didTapReceive = { [weak self] token in
      self?.openReceive(token: token)
    }
    
    module.output.didTapSend = { [weak self] token in
      self?.openSend(token: token)
    }
    
    router.push(viewController: module.view)
  }
  
  func openJettonDetails(jettonItem: JettonItem, wallet: Wallet) {
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
      tokenDetailsController: keeperCoreMainAssembly.jettonTokenDetailsController(jettonItem: jettonItem),
      chartViewControllerProvider: nil,
      hasAbout: false
    )
    
    module.output.didTapReceive = { [weak self] token in
      self?.openReceive(token: token)
    }
    
    module.output.didTapSend = { [weak self] token in
      self?.openSend(token: token)
    }
    
    router.push(viewController: module.view)
  }
  
  func openSend(token: Token) {
    let navigationController = TKNavigationController()
    navigationController.configureDefaultAppearance()
    
    let sendTokenCoordinator = SendModule(
      dependencies: SendModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createSendTokenCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      sendItem: .token(token, amount: 0)
    )
    
    sendTokenCoordinator.didFinish = { [weak self, weak sendTokenCoordinator, weak navigationController] in
      navigationController?.dismiss(animated: true)
      guard let sendTokenCoordinator else { return }
      self?.removeChild(sendTokenCoordinator)
    }
    
    addChild(sendTokenCoordinator)
    sendTokenCoordinator.start()
    
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
  
  func openEditWallet(wallet: Wallet, fromViewController: UIViewController) {
    let addWalletModuleModule = AddWalletModule(
      dependencies: AddWalletModule.Dependencies(
        walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly
      )
    )
    
    let module = addWalletModuleModule.createCustomizeWalletModule(
      name: wallet.metaData.label,
      tintColor: wallet.metaData.tintColor,
      emoji: wallet.metaData.emoji,
      configurator: EditWalletCustomizeWalletViewModelConfigurator()
    )
    
    module.output.didCustomizeWallet = { [weak self] model in
      self?.updateWallet(wallet: wallet, model: model)
    }
    
    let navigationController = TKNavigationController(rootViewController: module.view)
    
    module.view.setupRightCloseButton { [weak navigationController] in
      navigationController?.dismiss(animated: true)
    }
    
    fromViewController.present(navigationController, animated: true)
  }
  
  func updateWallet(wallet: Wallet, model: CustomizeWalletModel) {
    let controller = keeperCoreMainAssembly.walletUpdateAssembly.walletUpdateController()
    let metaData = WalletMetaData(
      label: model.name,
      tintColor: model.tintColor,
      emoji: model.emoji)
    do {
      try controller.updateWallet(wallet: wallet, metaData: metaData)
    } catch {
      print("Log: Wallet update failed")
    }
  }
}

extension WalletCoordinator: WalletContainerViewModelChildModuleProvider {
  func getWalletBalanceModuleView(wallet: Wallet) -> UIViewController {
    let walletBalanceController = keeperCoreMainAssembly.walletBalanceController(wallet: wallet)
    let module = WalletBalanceAssembly.module(walletBalanceController: walletBalanceController)
    
    module.output.didSelectTon = { [weak self] in
      self?.openTonDetails(wallet: wallet)
    }
    
    module.output.didSelectJetton = { [weak self] jettonItem in
      self?.openJettonDetails(jettonItem: jettonItem, wallet: wallet)
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
    
    module.output.didTapBackup = { [weak self] in
      self?.openBackup(wallet: wallet)
    }
    
    module.output.didRequireConfirmation = { [weak self] in
      return (await self?.openConfirmation()) ?? false
    }
    
    return module.view
  }
}
