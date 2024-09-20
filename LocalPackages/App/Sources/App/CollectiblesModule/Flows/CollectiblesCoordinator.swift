import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore
import TonSwift
import TKLocalize

public final class CollectiblesCoordinator: RouterCoordinator<NavigationControllerRouter> {
    
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
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
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
