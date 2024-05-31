import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore
import TonSwift
import TKLocalize

public final class CollectiblesCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didPerformTransaction: (() -> Void)?
  
  private weak var detailsCoordinator: CollectiblesDetailsCoordinator?
  
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  public init(router: NavigationControllerRouter,
              coreAssembly: TKCore.CoreAssembly,
              keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
    router.rootViewController.tabBarItem.title = TKLocales.Tabs.purchases
    router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.purchase
  }
  
  public override func start() {
    openCollectibles()
  }
  
  public func handleTonkeeperDeeplink(deeplink: TonkeeperDeeplink) -> Bool {
    if let detailsCoordinator = detailsCoordinator {
      return detailsCoordinator.handleTonkeeperDeeplink(deeplink: deeplink)
    }
    return false
  }
}

private extension CollectiblesCoordinator {
  func openCollectibles() {
    let module = CollectiblesAssembly.module(
      collectiblesController: keeperCoreMainAssembly.collectiblesController(), listModuleProvider: { [keeperCoreMainAssembly] wallet in
        CollectiblesListAssembly.module(
          collectiblesListController: keeperCoreMainAssembly.collectiblesListController(wallet: wallet)
        )
      }, emptyModuleProvider: { wallet in
        CollectiblesEmptyAssembly.module()
      })
    
    module.output.didSelectNFT = { [weak self] nft in
      self?.openNFTDetails(nft: nft)
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openNFTDetails(nft: NFT) {
    let navigationController = TKNavigationController()
    navigationController.configureDefaultAppearance()
    
    let coordinator = CollectiblesDetailsCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      nft: nft,
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    coordinator.didPerformTransaction = { [weak self] in
      self?.didPerformTransaction?()
    }
    
    coordinator.didClose = { [weak self, weak coordinator, weak navigationController] in
      navigationController?.dismiss(animated: true)
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    self.detailsCoordinator = coordinator
    
    coordinator.start()
    addChild(coordinator)
    
    router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    })
  }
}
