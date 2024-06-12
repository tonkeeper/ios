import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKCoordinator
import TonSwift

public final class PairLedgerCoordinator: RouterCoordinator<ViewControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didPaired: (() -> Void)?
  
  private let walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: ViewControllerRouter) {
    self.walletUpdateAssembly = walletUpdateAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  public override func start() {
    openConnectLedger()
  }
}

private extension PairLedgerCoordinator {
  func openConnectLedger() {
    let module = LedgerConnectAssembly.module(coreAssembly: coreAssembly)
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    bottomSheetViewController.didClose = { [weak self] isInteractivly in
      guard !isInteractivly else {
        self?.didCancel?()
        return
      }
    }

    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
}
