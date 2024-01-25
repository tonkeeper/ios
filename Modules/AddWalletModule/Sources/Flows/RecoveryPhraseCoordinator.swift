import UIKit
import KeeperCore
import TKCore
import TKCoordinator
import TKUIKit
import TKScreenKit

final class RecoveryPhraseCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didCancel: (() -> Void)?
  var didImportWallets: (([String], [WalletContractVersion]) -> Void)?

  public override func start() {
    openInputRecoveryPhrase()
  }
}

private extension RecoveryPhraseCoordinator {
  func openInputRecoveryPhrase() {
    let inputRecoveryPhrase = TKInputRecoveryPhraseAssembly.module(
      validator: InputRecoveryPhraseValidator(),
      suggestsProvider: InputRecoveryPhraseSuggestsProvider()
    )
    
    inputRecoveryPhrase.output.didInputRecoveryPhrase = { [weak self] phrase, completion in
      completion()
      self?.didImportWallets?(phrase, [.v4R2, .v4R1])
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      inputRecoveryPhrase.viewController.setupLeftCloseButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      inputRecoveryPhrase.viewController.setupBackButton()
    }
    
    router.push(
      viewController: inputRecoveryPhrase.viewController,
      animated: true,
      onPopClosures: { [weak self] in
        self?.didCancel?()
      },
      completion: nil)
  }
}
