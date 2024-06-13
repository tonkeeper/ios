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
    PasscodeInputCoordinator.present(
      parentCoordinator: self,
      parentRouter: router,
      repositoriesAssembly: keeperCoreMainAssembly.repositoriesAssembly,
      onCancel: { [weak self] in
        self?.didFinish?()
      },
      onInput: { [weak self, wallet, keeperCoreMainAssembly] passcode in
        guard let self else { return }
        Task {
          do {
            let mnemonic = try await keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository().getMnemonic(
              wallet: wallet,
              password: passcode
            )
            await MainActor.run {
              self.openRecoveryPhrase(mnemonic.mnemonicWords)
            }
          } catch {
            await MainActor.run {
              ToastPresenter.showToast(configuration: .failed)
            }
          }
        }
      }
    )
  }
  
  func openRecoveryPhrase(_ phrase: [String]) {
    let provider = SettingsRecoveryPhraseProvider(
      phrase: phrase
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
