import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore

final class SettingsRecoveryPhraseCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didFinish: (() -> Void)?
  
  private let wallet: Wallet
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(wallet: Wallet,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter) {
    self.wallet = wallet
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  public override func start() {
    let confirmationCoordinator = PasscodeModule(
      dependencies: PasscodeModule.Dependencies(
        passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
      )
    ).passcodeConfirmationCoordinator()
    confirmationCoordinator.didCancel = { [weak self, weak confirmationCoordinator] in
      confirmationCoordinator?.router.dismiss(completion: {
        self?.didFinish?()
        guard let confirmationCoordinator else { return }
        self?.removeChild(confirmationCoordinator)
      })
    }
    
    confirmationCoordinator.didConfirm = { [weak self, weak confirmationCoordinator] in
      confirmationCoordinator?.router.dismiss(completion: {
        self?.openRecoveryPhrase()
        guard let confirmationCoordinator else { return }
        self?.removeChild(confirmationCoordinator)
      })
    }
    
    addChild(confirmationCoordinator)
    confirmationCoordinator.start()
    
    router.present(confirmationCoordinator.router.rootViewController)
  }
  
  func openRecoveryPhrase() {
    let provider = SettingsRecoveryPhraseProvider(
      recoveryPhraseController: keeperCoreMainAssembly.recoveryPhraseController(wallet: wallet)
    )

    let module = TKRecoveryPhraseAssembly.module(
      provider: provider
    )
    
    let navigationController = TKNavigationController(rootViewController: module.viewController)
    navigationController.configureTransparentAppearance()
    
    module.viewController.setupLeftCloseButton { [weak self, weak navigationController] in
      navigationController?.dismiss(animated: true, completion: {
        self?.didFinish?()
      })
    }
    
    router.present(navigationController)
  }
}
