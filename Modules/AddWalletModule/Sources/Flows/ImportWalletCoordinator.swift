import UIKit
import KeeperCore
import TKCore
import TKCoordinator
import TKUIKit
import TKScreenKit

public final class ImportWalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didImportWallets: (() -> Void)?
  
  private let walletsUpdateAssembly: WalletsUpdateAssembly
  private let customizeWalletModule: () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>
  
  init(router: NavigationControllerRouter,
       walletsUpdateAssembly: WalletsUpdateAssembly,
       customizeWalletModule: @escaping () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>) {
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.customizeWalletModule = customizeWalletModule
    super.init(router: router)
  }

  public override func start() {
    openInputRecoveryPhrase()
  }
}

private extension ImportWalletCoordinator {
  func openInputRecoveryPhrase() {
    let coordinator = RecoveryPhraseCoordinator(
      router: router,
      walletsUpdateAssembly: walletsUpdateAssembly
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      self?.didCancel?()
    }
    
    coordinator.didImportWallets = { [weak self] phrase, revisions in
      self?.openCustomizeWallet(phrase: phrase, revisions: revisions)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openCustomizeWallet(phrase: [String], revisions: [WalletContractVersion]) {
    let module = customizeWalletModule()
    
    module.output.didCustomizeWallet = { [weak self] model in
      self?.importWallet(phrase: phrase,
                         revisions: revisions,
                         model: model)
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      module.view.setupLeftCloseButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      module.view.setupBackButton()
    }
    
    router.push(viewController: module.view)
  }
  
  func importWallet(phrase: [String],
                    revisions: [WalletContractVersion],
                    model: CustomizeWalletModel) {
    
    let addController = walletsUpdateAssembly.walletAddController()
    let metaData = WalletMetaData(
      label: model.name,
      colorIdentifier: model.colorIdentifier,
      emoji: model.emoji)
    do {
      try addController.importWallets(
        phrase: phrase,
        revisions: revisions,
        metaData: metaData)
      didImportWallets?()
    } catch {
      print("Log: Wallet import failed")
    }
  }
}
