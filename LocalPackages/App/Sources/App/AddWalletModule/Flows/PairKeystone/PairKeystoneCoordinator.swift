import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKCoordinator
import TonSwift

public final class PairKeystoneCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didPaired: (() -> Void)?
  
  private let scannerAssembly: KeeperCore.ScannerAssembly
  private let walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly
  private let coreAssembly: TKCore.CoreAssembly
  private let keystoneImportCoordinatorProvider: (NavigationControllerRouter, TonSwift.PublicKey, String?, String?, String) -> KeystoneImportCoordinator
  
  init(scannerAssembly: KeeperCore.ScannerAssembly,
       walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter,
       keystoneImportCoordinatorProvider: @escaping (NavigationControllerRouter, TonSwift.PublicKey, String?, String?, String) -> KeystoneImportCoordinator) {
    self.scannerAssembly = scannerAssembly
    self.walletUpdateAssembly = walletUpdateAssembly
    self.coreAssembly = coreAssembly
    self.keystoneImportCoordinatorProvider = keystoneImportCoordinatorProvider
    super.init(router: router)
  }
  
  public override func start() {
    openScanner()
  }
}

private extension PairKeystoneCoordinator {
  func openScanner() {
    let module = KeystoneImportScanAssembly.module(
      scannerAssembly: scannerAssembly,
      coreAssembly: coreAssembly
    )
    
    module.output.didScanQRCode = { [weak self] publicKey, xfp, path, name in
      self?.openImportCoordinator(publicKey: publicKey, xfp: xfp, path: path, name: name)
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
  
  func openImportCoordinator(publicKey: TonSwift.PublicKey,
                             xfp: String?, path: String?, name: String) {
    let coordinator = keystoneImportCoordinatorProvider(router, publicKey, xfp, path, name)
    
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
            xfp: xfp,
            path: path,
            revisions: revisions,
            model: model
          )
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
                    xfp: String?,
                    path: String?,
                    revisions: [WalletContractVersion],
                    model: CustomizeWalletModel
  ) async throws {
    let addController = walletUpdateAssembly.walletAddController()
    let metaData = WalletMetaData(
      label: model.name,
      tintColor: model.tintColor,
      icon: model.icon)
    try await addController.importKeystoneWallet(
      publicKey: publicKey,
      revisions: revisions,
      xfp: xfp,
      path: path,
      metaData: metaData
    )
  }
}
