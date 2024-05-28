import UIKit
import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct DNSModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createLinkDNSCoordinator(window: UIWindow, wallet: Wallet, nft: NFT, flow: LinkDNSCoordinator.Flow) -> LinkDNSCoordinator {
    LinkDNSCoordinator(
      router: WindowRouter(
        window: window
      ),
      wallet: wallet,
      flow: flow,
      linkDNSController: dependencies.keeperCoreMainAssembly.linkDNSController(wallet: wallet, nft: nft),
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
      coreAssembly: dependencies.coreAssembly
    )
  }
}

extension DNSModule {
  struct Dependencies {
    let coreAssembly: TKCore.CoreAssembly
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    
    public init(coreAssembly: TKCore.CoreAssembly,
                keeperCoreMainAssembly: KeeperCore.MainAssembly) {
      self.coreAssembly = coreAssembly
      self.keeperCoreMainAssembly = keeperCoreMainAssembly
    }
  }
}
