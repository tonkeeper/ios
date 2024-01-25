import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKScreenKit
import PasscodeModule

public final class OnboardingImportCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
//  public var didImportWallet: ((_ phrase: [String], _ model: CustomizeWalletModel) -> Void)?

  public override func start() {
//    openInputRecoveryPhrase()
  }
}

private extension OnboardingImportCoordinator {
  func openCreatePasscode() {
    let coordinator = PasscodeModule().createCreatePasscodeCoordinator(router: router)
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      self?.didCancel?()
    }
    
    coordinator.didCreatePasscode = { [weak self] passcode in
//      self?.openCustomizeWallet(passcode: passcode)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
}
