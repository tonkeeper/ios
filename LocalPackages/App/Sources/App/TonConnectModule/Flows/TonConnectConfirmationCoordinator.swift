import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKCore

final class TonConnectConfirmationCoordinator: RouterCoordinator<WindowRouter> {
  
  var didCancel: (() -> Void)?
  var didConfirm: (() -> Void)?
  
  private let tonConnectConfirmationController: TonConnectConfirmationController
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(router: WindowRouter,
       tonConnectConfirmationController: TonConnectConfirmationController,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly) {
    self.tonConnectConfirmationController = tonConnectConfirmationController
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  override func start() {
    ToastPresenter.showToast(configuration: .loading)
    Task {
      do {
        let model = try await tonConnectConfirmationController.createRequestModel()
        await MainActor.run {
          ToastPresenter.hideAll()
          openConfirmation(model: model)
        }
      } catch {
        await MainActor.run {
          ToastPresenter.hideAll()
        }
      }
    }
  }
}

private extension TonConnectConfirmationCoordinator {
  func openConfirmation(model: TonConnectConfirmationController.Model) {
    let rootViewController = UIViewController()
    router.window.rootViewController = rootViewController
    router.window.makeKeyAndVisible()
    
    let keyWindow = UIApplication.keyWindow
    
    let module = TonConnectConfirmationAssembly.module(
      model: model,
      historyEventMapper: HistoryEventMapper(accountEventActionContentProvider: TonConnectConfirmationAccountEventActionContentProvider())
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    bottomSheetViewController.didClose = { [weak self, weak tonConnectConfirmationController] isInteractivly in
      guard isInteractivly else { return }
      guard let tonConnectConfirmationController else { return }
      keyWindow?.makeKeyAndVisible()
      self?.didCancel?()
      Task {
        await tonConnectConfirmationController.cancel()
      }
    }
    
    module.output.didTapCancelButton = { [weak tonConnectConfirmationController, weak bottomSheetViewController] in
      guard let tonConnectConfirmationController else { return }
      Task {
        await tonConnectConfirmationController.cancel()
      }
      bottomSheetViewController?.dismiss(completion: { [weak self] in
        self?.didCancel?()
      })
    }
    
    module.output.didTapConfirmButton = { [weak self, weak bottomSheetViewController] in
      guard let bottomSheetViewController, let self else { return false }
      let isConfirmed = await self.openPasscodeConfirmation(fromViewController: bottomSheetViewController)
      guard isConfirmed else { return false }
      do {
        try await self.tonConnectConfirmationController.confirm()
        return true
      } catch {
        return false
      }
    }
    
    module.output.didConfirm = { [weak self, weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss(completion: { [weak self] in
        self?.didConfirm?()
      })
    }
    
    bottomSheetViewController.present(fromViewController: rootViewController)
  }
  
  func openPasscodeConfirmation(fromViewController: UIViewController) async -> Bool {
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
  
//  func openConfirmation(fromViewController: UIViewController) {
//    let coordinator = PasscodeModule(
//      dependencies: PasscodeModule.Dependencies(
//        passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
//      )
//    ).passcodeConfirmationCoordinator()
//    
//    coordinator.didCancel = { [weak self, weak coordinator] in
//      coordinator?.router.dismiss(completion: {
//        guard let coordinator else { return }
//        self?.removeChild(coordinator)
//      })
//    }
//    
//    coordinator.didConfirm = { [weak self, weak coordinator] in
//      coordinator?.router.dismiss(completion: {
//        guard let coordinator else { return }
//        self?.removeChild(coordinator)
//        
//        Task {
//          try await self?.tonConnectConfirmationController.confirm()
//        }
//      })
//    }
//    
//    self.addChild(coordinator)
//    coordinator.start()
//    
//    fromViewController.present(coordinator.router.rootViewController, animated: true)
//  }
}
