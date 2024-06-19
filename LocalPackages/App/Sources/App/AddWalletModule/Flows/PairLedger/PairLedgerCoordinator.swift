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
  private let publicKeyImportCoordinatorProvider: (NavigationControllerRouter, TonSwift.PublicKey, String) -> PublicKeyImportCoordinator
  
  init(walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: ViewControllerRouter,
       publicKeyImportCoordinatorProvider: @escaping (NavigationControllerRouter, TonSwift.PublicKey, String) -> PublicKeyImportCoordinator) {
    self.walletUpdateAssembly = walletUpdateAssembly
    self.coreAssembly = coreAssembly
    self.publicKeyImportCoordinatorProvider = publicKeyImportCoordinatorProvider
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
    
    module.output.didCancel = { [weak self, weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss(completion: {
        self?.didCancel?()
      })
    }
    
    module.output.didConnect = { [weak self, weak bottomSheetViewController] publicKey, name, device in
      bottomSheetViewController?.dismiss(completion: {
        self?.openImportCoordinator(publicKey: publicKey, name: name, device: device)
      })
    }

    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func openImportCoordinator(publicKey: TonSwift.PublicKey, name: String, device: Wallet.LedgerDevice) {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    let coordinator = publicKeyImportCoordinatorProvider(
      NavigationControllerRouter(
        rootViewController: navigationController
      ),
      publicKey,
      name
    )
    
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
            device: device,
            model: model)
          await MainActor.run {
            self.didPaired?()
          }
        } catch {
          print("Log: Wallet import failed \(error)")
        }
      }
    }
    
    coordinator.didPrepareForPresent = { [weak self, weak navigationController] in
      guard let navigationController else { return }
      self?.router.present(navigationController)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func importWallet(publicKey: TonSwift.PublicKey,
                    revisions: [WalletContractVersion],
                    device: Wallet.LedgerDevice,
                    model: CustomizeWalletModel) async throws {
    let addController = walletUpdateAssembly.walletAddController()
    let metaData = WalletMetaData(
      label: model.name,
      tintColor: model.tintColor,
      icon: .emoji(model.emoji))
    try addController.importLedgerWallet(
      publicKey: publicKey,
      revisions: revisions,
      device: device,
      metaData: metaData
    )
  }
}
