import UIKit
import KeeperCore
import TKCore
import TKCoordinator
import TKUIKit
import TKScreenKit
import TonSwift

public final class PairSignerImportCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didPrepareForPresent: (() -> Void)?
  public var didCancel: (() -> Void)?
  public var didPaired: (() -> Void)?
  
  private let publicKey: TonSwift.PublicKey
  private let name: String
  private let walletsUpdateAssembly: WalletsUpdateAssembly
  private let passcodeAssembly: KeeperCore.PasscodeAssembly
  private let passcode: String?
  private let customizeWalletModule: () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>
  
  init(publicKey: TonSwift.PublicKey,
       name: String,
       router: NavigationControllerRouter,
       walletsUpdateAssembly: WalletsUpdateAssembly,
       passcodeAssembly: KeeperCore.PasscodeAssembly,
       passcode: String?,
       customizeWalletModule: @escaping () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>) {
    self.publicKey = publicKey
    self.name = name
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.passcodeAssembly = passcodeAssembly
    self.passcode = passcode
    self.customizeWalletModule = customizeWalletModule
    super.init(router: router)
  }

  public override func start() {
    ToastPresenter.showToast(configuration: .loading)
    Task {
      do {
        let activeWalletModels = try await detectActiveWallets(publicKey: publicKey)
        await MainActor.run {
          if activeWalletModels.count > 1 {
            ToastPresenter.hideAll()
            openChooseWalletToAdd(publicKey: publicKey, activeWalletModels: activeWalletModels)
            didPrepareForPresent?()
          } else {
            ToastPresenter.hideAll()
            openCustomizeWallet(publicKey: publicKey, revisions: [.currentVersion], animated: true)
            didPrepareForPresent?()
          }
        }
      } catch {
        await MainActor.run {
          ToastPresenter.hideAll()
          openCustomizeWallet(publicKey: publicKey, revisions: [.currentVersion], animated: true)
          didPrepareForPresent?()
        }
      }
    }
  }
}

private extension PairSignerImportCoordinator {
  func detectActiveWallets(publicKey: TonSwift.PublicKey) async throws -> [ActiveWalletModel] {
    try await walletsUpdateAssembly.walletImportController().findActiveWallets(publicKey: publicKey, isTestnet: false)
  }
  
  func openChooseWalletToAdd(publicKey: TonSwift.PublicKey, activeWalletModels: [ActiveWalletModel]) {
    let controller = walletsUpdateAssembly.chooseWalletController(activeWalletModels: activeWalletModels)
    let module = ChooseWalletToAddAssembly.module(controller: controller)
    
    module.output.didSelectRevisions = { [weak self] revisions in
      self?.openCustomizeWallet(publicKey: publicKey, revisions: revisions, animated: true)
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
  
  func openCustomizeWallet(publicKey: TonSwift.PublicKey, revisions: [WalletContractVersion], animated: Bool) {
    let module = customizeWalletModule()
    
    module.output.didCustomizeWallet = { [weak self] model in
      self?.importWallet(publicKey: publicKey,
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
    
    router.push(viewController: module.view, animated: animated)
  }
  
  func importWallet(publicKey: TonSwift.PublicKey,
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
      try addController.importExternalWallet(
        publicKey: publicKey,
        revisions: revisions,
        metaData: metaData
      )
      didPaired?()
    } catch {
      print("Log: External wallet import failed")
    }
  }
}
