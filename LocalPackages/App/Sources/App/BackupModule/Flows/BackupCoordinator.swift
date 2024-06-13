import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore

final class BackupCoordinator: RouterCoordinator<NavigationControllerRouter> {
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
    // TODO: FIX!
    
//    let confirmationCoordinator = PasscodeModule(
//      dependencies: PasscodeModule.Dependencies(
//        passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
//      )
//    ).passcodeConfirmationCoordinator()
//    confirmationCoordinator.didCancel = { [weak self, weak confirmationCoordinator] in
//      confirmationCoordinator?.router.dismiss(completion: {
//        self?.didFinish?()
//        guard let confirmationCoordinator else { return }
//        self?.removeChild(confirmationCoordinator)
//      })
//    }
//    
//    confirmationCoordinator.didConfirm = { [weak self, weak confirmationCoordinator] in
//      confirmationCoordinator?.router.dismiss(completion: {
//        self?.openCheck()
//        guard let confirmationCoordinator else { return }
//        self?.removeChild(confirmationCoordinator)
//      })
//    }
//    
//    addChild(confirmationCoordinator)
//    confirmationCoordinator.start()
//    
//    router.present(confirmationCoordinator.router.rootViewController)
  }
  
  func openCheck() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let checkCoordinator = BackupCheckCoordinator(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly,
      router: NavigationControllerRouter(rootViewController: navigationController)
    )
    
    checkCoordinator.didFinish = { [weak self, weak checkCoordinator] in
      checkCoordinator?.router.rootViewController.dismiss(animated: true, completion: {
        self?.didFinish?()
        guard let checkCoordinator else { return }
        self?.removeChild(checkCoordinator)
      })
    }
    
    addChild(checkCoordinator)
    checkCoordinator.start()
    
    router.present(checkCoordinator.router.rootViewController,
                   onDismiss: { [weak self, weak checkCoordinator] in
      checkCoordinator?.router.rootViewController.dismiss(animated: true, completion: {
        self?.didFinish?()
        guard let checkCoordinator else { return }
        self?.removeChild(checkCoordinator)
      })
    })
  }
}
