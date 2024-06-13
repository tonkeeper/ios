import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKCoordinator
import TonSwift

public final class PairSignerDeeplinkCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didPaired: (() -> Void)?
  
  private let publicKey: TonSwift.PublicKey
  private let name: String
  private let walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly
  private let coreAssembly: TKCore.CoreAssembly
  private let publicKeyImportCoordinatorProvider: (NavigationControllerRouter, TonSwift.PublicKey, String) -> PublicKeyImportCoordinator
  
  init(publicKey: TonSwift.PublicKey,
       name: String,
       walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter,
       publicKeyImportCoordinatorProvider: @escaping (NavigationControllerRouter, TonSwift.PublicKey, String) -> PublicKeyImportCoordinator) {
    self.publicKey = publicKey
    self.name = name
    self.walletUpdateAssembly = walletUpdateAssembly
    self.coreAssembly = coreAssembly
    self.publicKeyImportCoordinatorProvider = publicKeyImportCoordinatorProvider
    super.init(router: router)
  }
  
  public override func start() {
    openImport()
  }
}

private extension PairSignerDeeplinkCoordinator {
  func openImport() {
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
            model: model)
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
                    model: CustomizeWalletModel) async throws {
    let addController = walletUpdateAssembly.walletAddController()
    let metaData = WalletMetaData(
      label: model.name,
      tintColor: model.tintColor,
      emoji: model.emoji)
    try addController.importExternalWallet(
      publicKey: publicKey,
      revisions: revisions,
      metaData: metaData
    )
  }
}
