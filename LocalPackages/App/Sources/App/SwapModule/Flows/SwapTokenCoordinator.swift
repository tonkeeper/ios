import UIKit
import TKCoordinator
import TKCore
import TKUIKit
import KeeperCore

final class SwapTokenCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didFinish: ((Bool) -> Void)?
  private var externalSignHandler: ((Data) async -> Void)?
  private let token: Token
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       token: Token) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.token = token
    super.init(router: router)
  }

  public override func start() {
    openSwap()
  }
}

private extension SwapTokenCoordinator {
  func openSwap() {
    let module = SwapAssembly.module(
      token: token,
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?(false)
    }
    module.output.didTapToken = { [weak self] (swapField, excludeToken) in
      guard let self else { return }
      self.openTokenPicker(
        sourceViewController: self.router.rootViewController,
        exclude: excludeToken,
        completion: { token in
          module.input.update(swapField: swapField, token: token)
        })
    }
    module.output.didContinueSwap = { [weak self] (swapItem, swapModel) in
      guard let self else { return }
      self.openSwapConfirmation(swapItem: swapItem, swapDetails: swapModel)
    }
    router.push(viewController: module.view, animated: false)
  }

  func openTokenPicker(sourceViewController: UIViewController, exclude: Token?, completion: @escaping (Token) -> Void) {
    let module = ChooseTokenAssembly.module(
      excludeToken: exclude,
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    let bottomSheetViewController = TKBottomSheetViewController(
      contentViewController: module.view,
      configuration: .init(dragHalfWayToClose: true)
    )
    module.output.didSelectToken = { [weak bottomSheetViewController] token in
      completion(token)
      bottomSheetViewController?.dismiss()
    }
    module.output.didFinish = { [weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss()
    }
    bottomSheetViewController.present(fromViewController: sourceViewController)
  }

  func openSwapConfirmation(swapItem: SwapItem, swapDetails: SwapView.Model) {
    let module = SwapConfirmationAssembly.module(
      swapItem: swapItem,
      swapDetails: swapDetails,
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    module.output.didRequireConfirmation = { [weak self] in
      guard let self else { return false }
      return await self.openConfirmation(fromViewController: self.router.rootViewController)
    }
    module.output.didSendTransaction = { [weak self] in
      NotificationCenter.default.post(Notification(name: Notification.Name("DID SEND TRANSACTION")))
      self?.router.dismiss(completion: {
        self?.didFinish?(true)
      })
    }
    module.output.didRequireExternalWalletSign = { [weak self] transferURL, wallet in
      guard let self else { return Data() }
      return try await self.handleExternalSign(url: transferURL,
                                               wallet: wallet,
                                               fromViewController: self.router.rootViewController)
    }
    module.output.didCancel = { [weak router] in
      router?.pop()
    }

    module.view.setupBackButton()
    router.push(viewController: module.view)
  }

  // TODO: - refactor it, duplicated from SentTokenCoordinator
  func openConfirmation(fromViewController: UIViewController) async -> Bool {
    return await Task<Bool, Never> { @MainActor in
      return await withCheckedContinuation { [weak self, keeperCoreMainAssembly] (continuation: CheckedContinuation<Bool, Never>) in
        guard let self = self else { return }
        let coordinator = PasscodeModule(
          dependencies: PasscodeModule.Dependencies(
            passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
          )
        ).passcodeConfirmationCoordinator()
        
        coordinator.didCancel = { [weak self, weak coordinator] in
          continuation.resume(returning: false)
          coordinator?.router.dismiss(completion: {
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
        
        coordinator.didConfirm = { [weak self, weak coordinator] in
          continuation.resume(returning: true)
          coordinator?.router.dismiss(completion: {
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
        
        self.addChild(coordinator)
        coordinator.start()
        
        fromViewController.present(coordinator.router.rootViewController, animated: true)
      }
    }.value
  }

  // TODO: - refactor it, duplicated from SentTokenCoordinator
  func handleExternalSign(url: URL, wallet: Wallet, fromViewController: UIViewController) async throws -> Data? {
    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        if self.coreAssembly.urlOpener().canOpen(url: url) {
          self.externalSignHandler = { data in
            continuation.resume(returning: data)
          }
          self.coreAssembly.urlOpener().open(url: url)
        } else {
          let module = SignerSignAssembly.module(
            url: url,
            wallet: wallet,
            assembly: self.keeperCoreMainAssembly,
            coreAssembly: self.coreAssembly
          )
          let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
          
          bottomSheetViewController.didClose = { isInteractivly in
            guard isInteractivly else { return }
            continuation.resume(returning: nil)
          }
          
          module.output.didScanSignedTransaction = { [weak bottomSheetViewController] model in
            bottomSheetViewController?.dismiss(completion: {
              continuation.resume(returning: model.boc)
            })
          }
          
          bottomSheetViewController.present(fromViewController: fromViewController)
        }
      }
    }
  }
}
