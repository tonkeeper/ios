import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore
import BigInt

struct SendModule {
  private let dependencies: Dependencies
  public init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  public func createSendTokenCoordinator(router: NavigationControllerRouter,
                                         wallet: Wallet,
                                         sendItem: SendItem,
                                         recipient: Recipient? = nil,
                                         comment: String? = nil) -> SendTokenCoordinator {
    let coordinator = SendTokenCoordinator(
      router: router,
      wallet: wallet,
      coreAssembly: dependencies.coreAssembly,
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
      sendItem: sendItem,
      recipient: recipient,
      comment: comment
    )
    return coordinator
  }
}

extension SendModule {
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
