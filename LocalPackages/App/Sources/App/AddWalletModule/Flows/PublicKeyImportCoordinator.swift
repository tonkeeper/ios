import UIKit
import KeeperCore
import TKCore
import TKCoordinator
import TKUIKit
import TKScreenKit
import TonSwift

public final class PublicKeyImportCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didPrepareForPresent: (() -> Void)?
  public var didCancel: (() -> Void)?
  public var didImport: ((_ publicKey: TonSwift.PublicKey, _ revisions: [WalletContractVersion], _ model: CustomizeWalletModel) -> Void)?
  
  private let publicKey: TonSwift.PublicKey
  private let name: String?
  private let walletsUpdateAssembly: WalletsUpdateAssembly
  private let customizeWalletModule: () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>
  
  init(publicKey: TonSwift.PublicKey,
       name: String?,
       router: NavigationControllerRouter,
       walletsUpdateAssembly: WalletsUpdateAssembly,
       customizeWalletModule: @escaping () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>) {
    self.publicKey = publicKey
    self.name = name
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.customizeWalletModule = customizeWalletModule
    super.init(router: router)
  }

  public override func start() {
    ToastPresenter.showToast(configuration: .loading)
    Task {
      do {
        let activeWalletModels = try await detectActiveWallets(publicKey: publicKey)
        await MainActor.run {
          ToastPresenter.hideAll()
          if activeWalletModels.count == 1, activeWalletModels[0].revision == WalletContractVersion.currentVersion {
            openCustomizeWallet(publicKey: publicKey, revisions: [.currentVersion])
          } else {
            openChooseWalletToAdd(publicKey: publicKey, activeWalletModels: activeWalletModels)
          }
          didPrepareForPresent?()
        }
      } catch {
        await MainActor.run {
          ToastPresenter.hideAll()
          openCustomizeWallet(publicKey: publicKey, revisions: [.currentVersion])
          didPrepareForPresent?()
        }
      }
    }
  }
}

private extension PublicKeyImportCoordinator {
  func detectActiveWallets(publicKey: TonSwift.PublicKey) async throws -> [ActiveWalletModel] {
    try await walletsUpdateAssembly.walletImportController().findActiveWallets(publicKey: publicKey, isTestnet: false)
  }
  
  func openChooseWalletToAdd(publicKey: TonSwift.PublicKey, activeWalletModels: [ActiveWalletModel]) {
    let module = ChooseWalletToAddAssembly.module(
      activeWalletModels: activeWalletModels,
      configuration: ChooseWalletToAddConfiguration(
        showRevision: true,
        selectLastRevision: true
      ),
      amountFormatter: walletsUpdateAssembly.formattersAssembly.amountFormatter
    )
    
    module.output.didSelectWallets = { [weak self] wallets in
      let revisions = wallets.map { $0.revision }
      self?.openCustomizeWallet(publicKey: publicKey, revisions: revisions)
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      module.view.setupLeftCloseButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      module.view.setupBackButton()
    }
    
    router.push(
      viewController: module.view,
      animated: true,
      onPopClosures: { [weak self] in self?.didCancel?() },
      completion: nil)
  }
  
  func openCustomizeWallet(publicKey: TonSwift.PublicKey, revisions: [WalletContractVersion]) {
    let module = customizeWalletModule()
    
    module.output.didCustomizeWallet = { [weak self] model in
      self?.didImport?(publicKey, revisions, model)
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      module.view.setupLeftCloseButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      module.view.setupBackButton()
    }
    
    router.push(viewController: module.view, animated: true)
  }
}
