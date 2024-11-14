import UIKit
import KeeperCore
import TKCore
import TKCoordinator
import TKUIKit
import TKScreenKit
import TonSwift

public final class KeystoneImportCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didPrepareForPresent: (() -> Void)?
  public var didCancel: (() -> Void)?
  public var didImport: ((_ publicKey: TonSwift.PublicKey, _ revisions: [WalletContractVersion], _ model: CustomizeWalletModel) -> Void)?
  
  private let publicKey: TonSwift.PublicKey
  private let name: String?
  private let path: String?
  private let xfp: String?
  private let walletsUpdateAssembly: WalletsUpdateAssembly
  private let customizeWalletModule: () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>
  
  init(publicKey: TonSwift.PublicKey,
       xfp: String?,
       path: String?,
       name: String?,
       router: NavigationControllerRouter,
       walletsUpdateAssembly: WalletsUpdateAssembly,
       customizeWalletModule: @escaping () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>) {
    self.publicKey = publicKey
    self.name = name
    self.xfp = xfp
    self.path = path
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.customizeWalletModule = customizeWalletModule
    super.init(router: router)
  }

  public override func start() {
    Task {
      await MainActor.run {
        openCustomizeWallet(publicKey: publicKey, revisions: [.v4R2])
        didPrepareForPresent?()
      }
    }
  }
}

private extension KeystoneImportCoordinator {
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
