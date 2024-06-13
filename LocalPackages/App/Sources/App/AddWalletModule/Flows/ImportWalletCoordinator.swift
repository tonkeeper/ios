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
  private let passcodeAssembly: KeeperCore.PasscodeAssembly
  private let passcode: String?
  private let isTestnet: Bool
  private let customizeWalletModule: () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>
  
  init(router: NavigationControllerRouter,
       walletsUpdateAssembly: WalletsUpdateAssembly,
       passcodeAssembly: KeeperCore.PasscodeAssembly,
       passcode: String?,
       isTestnet: Bool,
       customizeWalletModule: @escaping () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>) {
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.passcodeAssembly = passcodeAssembly
    self.passcode = passcode
    self.isTestnet = isTestnet
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
      walletsUpdateAssembly: walletsUpdateAssembly,
      isTestnet: isTestnet
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
      tintColor: model.tintColor,
      emoji: model.emoji)
    do {
      if let passcode {
        try passcodeAssembly.passcodeCreateController().createPasscode(passcode)
      }
      try addController.importWallets(
        phrase: phrase,
        revisions: revisions,
        metaData: metaData,
        isTestnet: isTestnet)
      didImportWallets?()
    } catch {
      print("Log: Wallet import failed, error: \(error)")
    }
  }
}
