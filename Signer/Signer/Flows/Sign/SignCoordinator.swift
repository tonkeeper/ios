import UIKit
import SignerCore
import TKCoordinator
import TKUIKit

final class SignCoordinator: RouterCoordinator<WindowRouter> {
  
  var didCancel: (() -> Void)?
  
  private let model: TonSignModel
  private let walletKey: WalletKey
  private let signerCoreAssembly: SignerCore.Assembly
  
  init(router: WindowRouter,
       model: TonSignModel,
       walletKey: WalletKey,
       signerCoreAssembly: SignerCore.Assembly) {
    self.model = model
    self.walletKey = walletKey
    self.signerCoreAssembly = signerCoreAssembly
    super.init(router: router)
  }
  
  override func start() {
    openSignConfirmation()
  }
}

private extension SignCoordinator {
  func openSignConfirmation() {
    let rootViewController = UIViewController()
    router.window.rootViewController = rootViewController
    router.window.makeKeyAndVisible()
    
    let module = SignConfirmationAssembly.module(
      signerCoreAssembly: signerCoreAssembly,
      model: model,
      walletKey: walletKey
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    bottomSheetViewController.didClose = { [weak self] isInteractivly in
      guard isInteractivly else { return }
      self?.didCancel?()
    }
    
    module.output.didSignTransaction = { [weak self, weak bottomSheetViewController] url, walletKey, hexBody in
      bottomSheetViewController?.dismiss(completion: {
        self?.handleSignURL(url, walletKey: walletKey, hexBody: hexBody)
      })
    }
    
    bottomSheetViewController.present(fromViewController: rootViewController)
  }
  
  func handleSignURL(_ url: URL, walletKey: WalletKey, hexBody: String) {
    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url: url)
    }
    openSignQRCode(url: url, walletKey: walletKey, hexBody: hexBody)
  }
  
  func openSignQRCode(url: URL, walletKey: WalletKey, hexBody: String) {
    let module = SignQRCodeAssembly.module(
      signerCoreAssembly: signerCoreAssembly,
      url: url,
      walletKey: walletKey,
      hexBody: hexBody
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    bottomSheetViewController.didClose = { [weak self] isInteractivly in
      self?.didCancel?()
    }
    
    module.output.didTapDone = { [weak self, weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss(completion: {
        self?.didCancel?()
      })
    }
    
    guard let rootViewController = router.window.rootViewController else { return }
    bottomSheetViewController.present(fromViewController: rootViewController)
  }
}
