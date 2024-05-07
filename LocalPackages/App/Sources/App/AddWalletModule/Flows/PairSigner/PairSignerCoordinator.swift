import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKCoordinator
import TonSwift

public final class PairSignerCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didPaired: (() -> Void)?
  
  private let scannerAssembly: KeeperCore.ScannerAssembly
  private let walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly
  private let coreAssembly: TKCore.CoreAssembly
  private let pairSignerImportCoordinatorProvider: (NavigationControllerRouter, TonSwift.PublicKey, String) -> PairSignerImportCoordinator
  
  init(scannerAssembly: KeeperCore.ScannerAssembly,
       walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter,
       pairSignerImportCoordinatorProvider: @escaping (NavigationControllerRouter, TonSwift.PublicKey, String) -> PairSignerImportCoordinator) {
    self.scannerAssembly = scannerAssembly
    self.walletUpdateAssembly = walletUpdateAssembly
    self.coreAssembly = coreAssembly
    self.pairSignerImportCoordinatorProvider = pairSignerImportCoordinatorProvider
    super.init(router: router)
  }
  
  public override func start() {
    openScanner()
  }
  
  public override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
    guard let signerDeeplink = deeplink as? TonkeeperDeeplink.SignerDeeplink else { return false }
    switch signerDeeplink {
    case let .link(publicKey, name):
      openImportCoordinator(publicKey: publicKey, name: name)
      return true
    }
  }
}

private extension PairSignerCoordinator {
  func openScanner() {
    let module = SignerImportScanAssembly.module(
      scannerAssembly: scannerAssembly,
      coreAssembly: coreAssembly
    )
    
    module.output.didScanLinkQRCode = { [weak self] publicKey, name in
      self?.openImportCoordinator(publicKey: publicKey, name: name)
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      module.view.setupSwipeDownButton() { [weak self] in
        self?.didCancel?()
      }
    } else {
      module.view.setupBackButton()
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openImportCoordinator(publicKey: TonSwift.PublicKey, name: String) {
    let coordinator = pairSignerImportCoordinatorProvider(router, publicKey, name)
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didPaired = { [weak self, weak coordinator] in
      self?.didPaired?()
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
}
