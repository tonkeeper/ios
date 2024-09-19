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
    openWarning()
  }
  
  func openWarning() {
    let viewController = BackupWarningViewController()
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
    
    viewController.didTapContinue = { [weak bottomSheetViewController, weak self] in
      bottomSheetViewController?.dismiss(completion: {
        self?.openPasscodeInput()
      })
    }
    
    viewController.didTapCancel = { [weak bottomSheetViewController, weak self] in
      bottomSheetViewController?.dismiss(completion: {
        self?.didFinish?()
      })
    }
    
    bottomSheetViewController.didClose = { [weak self] isInteractivly in
      guard !isInteractivly else {
        self?.didFinish?()
        return
      }
      self?.openPasscodeInput()
    }
    
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func openPasscodeInput() {
    PasscodeInputCoordinator.present(
      parentCoordinator: self,
      parentRouter: router,
      mnemonicsRepository: keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository(),
      securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
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
              self.openCheck(phrase: mnemonic.mnemonicWords)
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
  
  func openCheck(phrase: [String]) {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let checkCoordinator = BackupCheckCoordinator(
      wallet: wallet,
      phrase: phrase,
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
