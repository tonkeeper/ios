import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize

public final class HistoryCoordinator: RouterCoordinator<NavigationControllerRouter> {
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
    router.rootViewController.tabBarItem.title = TKLocales.Tabs.history
    router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.clock
  }
  
  public override func start() {
    openHistory()
  }
}

private extension HistoryCoordinator {
  func openHistory() {
    let module = HistoryAssembly.module(
      historyController: keeperCoreMainAssembly.historyController(),
      listModuleProvider: { [keeperCoreMainAssembly] wallet in
        HistoryListAssembly.module(
          historyListController: keeperCoreMainAssembly.historyListController(wallet: wallet),
          historyEventMapper: HistoryEventMapper(accountEventActionContentProvider: HistoryListAccountEventActionContentProvider())
        )
      },
      emptyModuleProvider: { wallet in
        HistoryEmptyAssembly.module()
      }
    )
    
    module.output.didTapReceive = { [weak self] in
      self?.openReceive()
    }
    
    module.output.didTapBuy = { [weak self] wallet in
      self?.openBuy(wallet: wallet)
    }
    
    module.output.didSelectEvent = { [weak self] event in
      self?.openEventDetails(event: event)
    }
    
    module.output.didSelectNFT = { [weak self] nft in
      self?.openNFTDetails(nft: nft)
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openReceive() {
    let module = ReceiveModule(
      dependencies: ReceiveModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).receiveModule(token: .ton)
    
    module.view.setupSwipeDownButton()
    
    let navigationController = TKNavigationController(rootViewController: module.view)
    navigationController.configureTransparentAppearance()
    
    router.present(navigationController)
  }
  
  func openBuy(wallet: Wallet) {
    let navigationController = TKNavigationController()
    navigationController.configureDefaultAppearance()
    
    let coordinator = BuyCoordinator(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly,
      router: NavigationControllerRouter(rootViewController: navigationController)
    )
    
    coordinator.didFinish = { [weak self, weak coordinator, weak navigationController] in
      navigationController?.dismiss(animated: true)
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
    
    router.present(navigationController)
  }
  
  func openEventDetails(event: AccountEventDetailsEvent) {
    let module = HistoryEventDetailsAssembly.module(
      historyEventDetailsController: keeperCoreMainAssembly.historyEventDetailsController(event: event),
      urlOpener: coreAssembly.urlOpener()
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func openNFTDetails(nft: NFT) {
    let module = CollectibleDetailsAssembly.module(
      collectibleDetailsController: keeperCoreMainAssembly.collectibleDetailsController(nft: nft),
      urlOpener: coreAssembly.urlOpener(),
      output: self
    )
    
    let navigationController = TKNavigationController(rootViewController: module.0)
    navigationController.configureDefaultAppearance()
    router.present(navigationController)
  }
}

extension HistoryCoordinator: CollectibleDetailsModuleOutput {
  func collectibleDetailsDidFinish(_ collectibleDetails: CollectibleDetailsModuleInput) {}
  
  func collectibleDetails(_ collectibleDetails: CollectibleDetailsModuleInput, transferNFT nft: KeeperCore.NFT) {
    let navigationController = TKNavigationController()
    navigationController.configureDefaultAppearance()
    
    let sendTokenCoordinator = SendModule(
      dependencies: SendModule.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
    ).createSendTokenCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      sendItem: .nft(nft)
    )
    
    sendTokenCoordinator.didFinish = { [weak self, weak sendTokenCoordinator, weak navigationController] in
      navigationController?.dismiss(animated: true)
      guard let sendTokenCoordinator else { return }
      self?.removeChild(sendTokenCoordinator)
    }
    
    addChild(sendTokenCoordinator)
    sendTokenCoordinator.start()
    
    self.router.rootViewController.presentedViewController?.present(navigationController, animated: true)
  }
}
