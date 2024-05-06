import UIKit
import SignerCore
import TKCoordinator
import TKUIKit

final class SignCoordinator: RouterCoordinator<WindowRouter> {
  
  var didCancel: (() -> Void)?
  
  private let model: TonSignModel
  private let walletKey: WalletKey
  private let scanner: Bool
  private let signerCoreAssembly: SignerCore.Assembly
  
  init(router: WindowRouter,
       model: TonSignModel,
       walletKey: WalletKey,
       scanner: Bool,
       signerCoreAssembly: SignerCore.Assembly) {
    self.model = model
    self.walletKey = walletKey
    self.scanner = scanner
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
    
    module.output.didRequireConfirmation = { [weak self, weak bottomSheetViewController] completion in
      guard let bottomSheetViewController else { return }
      self?.openEnterPassword(fromViewController: bottomSheetViewController, completion: completion)
    }
    
    module.output.didSignTransaction = { [weak self, weak bottomSheetViewController] url, walletKey, hexBody in
      bottomSheetViewController?.dismiss(completion: {
        self?.handleSignURL(url, walletKey: walletKey, hexBody: hexBody)
      })
    }
    
    bottomSheetViewController.present(fromViewController: rootViewController)
  }
  
  func handleSignURL(_ url: URL, walletKey: WalletKey, hexBody: String) {
    if scanner {
      openSignQRCode(url: url, walletKey: walletKey, hexBody: hexBody)
    } else if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url: url)
      didCancel?()
    } else {
      openSignQRCode(url: url, walletKey: walletKey, hexBody: hexBody)
    }
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
  
  func openEnterPassword(fromViewController: UIViewController, completion: @escaping (Bool) -> Void) {
    let configurator = EnterPasswordPasswordInputViewModelConfigurator(
      passwordRepository: signerCoreAssembly.repositoriesAssembly.passwordRepository()
    )
    let module = PasswordInputModuleAssembly.module(configurator: configurator)
    module.output.didEnterPassword = { [weak view = module.view] _ in
      view?.dismiss(animated: true) {
        completion(true)
      }
    }
    
    module.view.setupLeftCloseButton { [weak view = module.view] in
      completion(false)
      view?.dismiss(animated: true)
    }
    
    let navigationController = TKNavigationController(rootViewController: module.view)
    navigationController.configureTransparentAppearance()
    
    fromViewController.present(navigationController, animated: true)
  }
}
