import UIKit
import TKUIKit
import TKCoordinator
import SignerCore
import SignerLocalize

final class KeyDetailsCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  private let signerCoreAssembly: SignerCore.Assembly
  private let walletKey: WalletKey
  
  init(router: NavigationControllerRouter,
       signerCoreAssembly: SignerCore.Assembly,
       walletKey: WalletKey) {
    self.signerCoreAssembly = signerCoreAssembly
    self.walletKey = walletKey
    super.init(router: router)
  }
  
  var didFinish: (() -> Void)?

  override func start() {
    openKeyDetails()
  }
}

private extension KeyDetailsCoordinator {
  func openKeyDetails() {
    let module = KeyDetailsModuleAssembly.module(
      walletKey: walletKey,
      signerCoreAssembly: signerCoreAssembly
    )
    module.view.setupBackButton()
    module.output.didDeleteKey = { [weak self] in
      self?.router.pop()
    }
    module.output.didTapEdit = { [weak self] in
      self?.openEditName()
    }
    module.output.didTapOpenRecoveryPhrase = { [weak self] in
      self?.openRecoveryPhrase()
    }
    module.output.didRequireConfirmation = { [weak self] completion in
      guard let self else { return }
      self.openEnterPassword(fromViewController: self.router.rootViewController, completion: { password in
        completion(password != nil)
      })
    }
    module.output.didRequirePassword = { [weak self] completion in
      guard let self else { return }
      self.openEnterPassword(fromViewController: self.router.rootViewController, completion: completion)
    }

    router.push(viewController: module.view,
                animated: true,
                onPopClosures: { [weak self] in
      self?.didFinish?()
    })
  }

  func openEditName() {
    let module = EditWalletNameModuleAssembly.module(
      configurator: EditEditWalletNameViewModelConfigurator(),
      defaultName: walletKey.name
    )
    module.view.setupRightCloseButton { [weak self] in
      self?.router.dismiss()
    }
    module.output.didEnterWalletName = { [signerCoreAssembly, walletKey, weak self] name in
      try? signerCoreAssembly.keysEditController().updateWalletKeyName(walletKey: walletKey, name: name)
      self?.router.dismiss()
    }
    
    let navigationController = NavigationController(rootViewController: module.view)
    navigationController.configureTransparentAppearance()
    
    router.present(navigationController)
  }
  
  func openRecoveryPhrase() {
    let navigationController = NavigationController()
    navigationController.configureTransparentAppearance()
    
    let coordinator = ShowRecoveryPhraseCoordinator(
      router: .init(rootViewController: navigationController),
      assembly: signerCoreAssembly,
      walletKey: walletKey
    )
    coordinator.didFinish = { [weak self, unowned coordinator] in
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
    
    navigationController.modalPresentationStyle = .fullScreen
    router.present(navigationController)
  }
  
  func openEnterPassword(fromViewController: UIViewController, completion: @escaping (String?) -> Void) {
    let configurator = EnterPasswordPasswordInputViewModelConfigurator(
      mnemonicsRepository: signerCoreAssembly.repositoriesAssembly.mnemonicsRepository(),
      title: SignerLocalize.Password.Enter.title
    )
    let module = PasswordInputModuleAssembly.module(configurator: configurator)
    module.output.didEnterPassword = { [weak view = module.view] password in
      completion(password)
      view?.dismiss(animated: true)
    }
    
    module.view.setupLeftCloseButton { [weak view = module.view] in
      completion(nil)
      view?.dismiss(animated: true)
    }
    
    let navigationController = TKNavigationController(rootViewController: module.view)
    navigationController.configureTransparentAppearance()
    
    fromViewController.present(navigationController, animated: true)
  }
}
