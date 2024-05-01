import UIKit
import TKScreenKit
import SignerCore

final class ShowRecoveryPhraseCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  
  private let assembly: SignerCore.Assembly
  private let walletKey: WalletKey
  
  init(router: NavigationControllerRouter, 
       assembly: SignerCore.Assembly,
       walletKey: WalletKey) {
    self.assembly = assembly
    self.walletKey = walletKey
    super.init(router: router)
  }
  
  override func start() {
    openEnterPassword()
  }
}

private extension ShowRecoveryPhraseCoordinator {
  func openEnterPassword() {
    let configurator = EnterPasswordPasswordInputViewModelConfigurator(
      passwordRepository: assembly.repositoriesAssembly.passwordRepository()
    )
    let module = PasswordInputModuleAssembly.module(configurator: configurator)
    module.output.didEnterPassword = { [weak self] _ in
      self?.openRecoveryPhrase()
    }
    
    module.view.setCloseButton { [weak self, weak view = module.view] in
      view?.dismiss(animated: true) { [weak self] in
        self?.didFinish?()
      }
    }

    router.push(viewController: module.view,
                onPopClosures: {})
  }
  
  func openRecoveryPhrase() {

    let module = ShowRecoveryPhraseModuleAssembly.module(assembly: assembly, walletKey: walletKey)
    module.view.setCloseButton { [weak self, weak view = module.view] in
      view?.dismiss(animated: true) { [weak self] in
        self?.didFinish?()
      }
    }
    router.setViewControllers([(module.view, nil)])
  }
}