import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore
import TonSwift
import TKLocalize

public final class CollectiblesCoordinator: RouterCoordinator<NavigationControllerRouter> {
    
  var didOpenDapp: ((_ url: URL, _ title: String?) -> Void)?
  var didRequestDeeplinkHandling: ((_ deeplink: Deeplink) -> Void)?

  private weak var detailsCoordinator: CollectiblesDetailsCoordinator?

  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let parentRouter: TabBarControllerRouter?
  private let recipientResolver: RecipientResolver

  public init(router: NavigationControllerRouter,
              parentRouter: TabBarControllerRouter?,
              coreAssembly: TKCore.CoreAssembly,
              keeperCoreMainAssembly: KeeperCore.MainAssembly,
              recipientResolver: RecipientResolver) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.parentRouter = parentRouter
    self.recipientResolver = recipientResolver
    super.init(router: router)
    router.rootViewController.tabBarItem.title = TKLocales.Tabs.collectibles
    router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.purchase
  }
  
  public override func start() {
    openCollectibles()
  }
  
  public func handleTonkeeperDeeplink(deeplink: Deeplink) -> Bool {
    if let detailsCoordinator = detailsCoordinator {
      return detailsCoordinator.handleTonkeeperDeeplink(deeplink: deeplink)
    }
    return false
  }
}

private extension CollectiblesCoordinator {

  func openCollectibles() {
    let module = CollectiblesContainerAssembly.module(keeperCoreMainAssembly: keeperCoreMainAssembly)
    
    module.output.didChangeWallet = { [weak self, keeperCoreMainAssembly] wallet in
      let listModule = CollectiblesListAssembly.module(
        wallet: wallet,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
      
      listModule.output.didSelectNFT = { nft, wallet in
        self?.openNFTDetails(wallet: wallet, nft: nft)
      }
      
      let collectiblesModule = CollectiblesAssembly.module(
        wallet: wallet,
        collectiblesListViewController: listModule.view,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )

      collectiblesModule.output.didTapCollectiblesDetails = { [weak self] in
        guard let self else {
          return
        }
        self.openPurchases(wallet: wallet)
      }

      module.view.collectiblesViewController = collectiblesModule.view
      
    }
    router.push(viewController: module.view, animated: false)
  }

  func openNFTDetails(wallet: Wallet, nft: NFT) {
    let navigationController = TKNavigationController()
    navigationController.setNavigationBarHidden(true, animated: false)
    
    let coordinator = CollectiblesDetailsCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      nft: nft,
      wallet: wallet,
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      recipientResolver: recipientResolver
    )
    
    coordinator.didOpenDapp = { [weak self] url, title in
      self?.didOpenDapp?(url, title)
    }
    
    coordinator.didClose = { [weak self, weak coordinator, weak navigationController] in
      navigationController?.dismiss(animated: true)
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }

    coordinator.didRequestDeeplinkHandling = { [weak self] deeplink in
      self?.didRequestDeeplinkHandling?(deeplink)
    }

    self.detailsCoordinator = coordinator
    
    coordinator.start()
    addChild(coordinator)
    
    router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    })
  }

  func openPurchases(wallet: Wallet) {
    let module = SettingsPurchasesAssembly.module(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )

    module.view.setupBackButton()
    guard let navigationController = parentRouter?.rootViewController.navigationController else {
      router.push(viewController: module.view)
      return
    }

    navigationController.pushViewController(module.view, animated: true)
  }
}
