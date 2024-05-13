import UIKit
import SignerCore
import SignerLocalize
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
    
    module.output.didRequirePassword = { [weak self, weak bottomSheetViewController] completion in
      guard let bottomSheetViewController else { return }
      self?.openEnterPassword(fromViewController: bottomSheetViewController, completion: completion)
    }
    
    module.output.didSignTransaction = { [weak self, weak bottomSheetViewController] url, walletKey, hexBody in
      bottomSheetViewController?.dismiss(completion: {
        self?.handleSignURL(url, walletKey: walletKey, hexBody: hexBody)
      })
    }
    
    module.output.didOpenEmulateURL = { url in
      UIApplication.shared.open(url: url)
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
  
  func openEnterPassword(fromViewController: UIViewController, completion: @escaping (String?) -> Void) {
    let configurator = EnterPasswordPasswordInputViewModelConfigurator(
      mnemonicsRepository: signerCoreAssembly.repositoriesAssembly.mnemonicsRepository(),
      title: SignerLocalize.Password.Enter.title
    )
    let module = PasswordInputModuleAssembly.module(configurator: configurator)
    module.output.didEnterPassword = { [weak view = module.view] password in
      view?.dismiss(animated: true) {
        completion(password)
      }
    }
    
    module.view.setupLeftCloseButton { [weak view = module.view] in
      completion(nil)
      view?.dismiss(animated: true)
    }
    
    let navigationController = TKNavigationController(rootViewController: module.view)
    navigationController.configureTransparentAppearance()
    navigationController.modalTransitionStyle = .crossDissolve
    
    fromViewController.present(navigationController, animated: true)
  }
}
