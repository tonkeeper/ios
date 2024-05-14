import UIKit
import KeeperCore
import TKCore
import TKCoordinator
import TKUIKit
import TKScreenKit

public final class CreateWalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didCreateWallet: (() -> Void)?
  
  private let walletsUpdateAssembly: WalletsUpdateAssembly
  private let passcodeAssembly: KeeperCore.PasscodeAssembly
  private let passcode: String?
  private let customizeWalletModule: () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>
  
  init(router: NavigationControllerRouter,
       walletsUpdateAssembly: WalletsUpdateAssembly,
       passcodeAssembly: KeeperCore.PasscodeAssembly,
       passcode: String?,
       customizeWalletModule: @escaping () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>) {
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.passcodeAssembly = passcodeAssembly
    self.passcode = passcode
    self.customizeWalletModule = customizeWalletModule
    super.init(router: router)
  }

  public override func start() {
    openCustomizeWallet()
  }
}

private extension CreateWalletCoordinator {
  func openCustomizeWallet() {
    let module = customizeWalletModule()
    
    module.output.didCustomizeWallet = { [weak self] model in
      self?.createWallet(model: model)
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      module.view.setupLeftCloseButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      module.view.setupBackButton()
    }
    
    router.push(viewController: module.view, onPopClosures: { [weak self] in
      self?.didCancel?()
    })
  }
  
  func createWallet(model: CustomizeWalletModel) {
    let addController = walletsUpdateAssembly.walletAddController()
    let metaData = WalletMetaData(
      label: model.name,
      tintColor: model.tintColor,
      emoji: model.emoji)
    do {
      if let passcode {
        try passcodeAssembly.passcodeCreateController().createPasscode(passcode)
      }
      try addController.createWallet(metaData: metaData)
      didCreateWallet?()
    } catch {
      print("Log: Wallet creation failed")
    }
  }
}
