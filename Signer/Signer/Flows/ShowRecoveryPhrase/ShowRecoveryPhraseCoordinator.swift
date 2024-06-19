import UIKit
import TKScreenKit
import TKCoordinator
import SignerCore
import SignerLocalize

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
      mnemonicsRepository: assembly.repositoriesAssembly.mnemonicsRepository(),
      oldMnemonicRepository: assembly.repositoriesAssembly.oldMnemonicRepository(),
      title: SignerLocalize.Password.Confirmation.title
    )
    let module = PasswordInputModuleAssembly.module(configurator: configurator)
    module.output.didEnterPassword = { [weak self] password in
      self?.openRecoveryPhrase(password: password)
    }
    
    module.view.setupLeftCloseButton { [weak self, weak view = module.view] in
      view?.dismiss(animated: true) { [weak self] in
        self?.didFinish?()
      }
    }

    router.push(viewController: module.view,
                onPopClosures: {})
  }
  
  func openRecoveryPhrase(password: String) {
    let module = TKRecoveryPhraseAssembly.module(
      provider: RecoveryPhraseDataProvider(
        recoveryPhraseController: assembly.recoveryPhraseController(
          walletKey: walletKey,
          password: password
        )
      )
    )
    
    module.viewController.setupLeftCloseButton { [weak self, weak view = module.viewController] in
      view?.dismiss(animated: true) { [weak self] in
        self?.didFinish?()
      }
    }
    router.setViewControllers([(module.viewController, nil)])
  }
}
