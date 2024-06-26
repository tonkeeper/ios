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
  private let publicKeyImportCoordinatorProvider: (NavigationControllerRouter, TonSwift.PublicKey, String) -> PublicKeyImportCoordinator
  
  init(scannerAssembly: KeeperCore.ScannerAssembly,
       walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter,
       publicKeyImportCoordinatorProvider: @escaping (NavigationControllerRouter, TonSwift.PublicKey, String) -> PublicKeyImportCoordinator) {
    self.scannerAssembly = scannerAssembly
    self.walletUpdateAssembly = walletUpdateAssembly
    self.coreAssembly = coreAssembly
    self.publicKeyImportCoordinatorProvider = publicKeyImportCoordinatorProvider
    super.init(router: router)
  }
  
  public override func start() {
    openScanner()
  }
  
  public override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
    guard let signerDeeplink = deeplink as? TonkeeperDeeplink.SignerDeeplink else { return false }
    switch signerDeeplink {
    case let .link(publicKey, name):
      openImportCoordinator(publicKey: publicKey, name: name, isDevice: true)
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
      self?.openImportCoordinator(publicKey: publicKey, name: name, isDevice: false)
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
  
  func openImportCoordinator(publicKey: TonSwift.PublicKey, name: String, isDevice: Bool) {
    let coordinator = publicKeyImportCoordinatorProvider(router, publicKey, name)
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didImport = { [weak self] publicKey, revisions, model in
      guard let self else { return }
      Task {
        do {
          try await self.importWallet(
            publicKey: publicKey,
            revisions: revisions,
            model: model, 
            isDevice: isDevice)
          await MainActor.run {
            self.didPaired?()
          }
        } catch {
          print("Log: Wallet import failed \(error)")
        }
      }
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func importWallet(publicKey: TonSwift.PublicKey,
                    revisions: [WalletContractVersion],
                    model: CustomizeWalletModel,
                    isDevice: Bool) async throws {
    let addController = walletUpdateAssembly.walletAddController()
    let metaData = WalletMetaData(
      label: model.name,
      tintColor: model.tintColor,
      icon: model.icon)
    try addController.importSignerWallet(publicKey: publicKey,
                                         revisions: revisions,
                                         metaData: metaData,
                                         isDevice: isDevice
    )
  }
}
