//
//  TonConnectCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 25.10.2023.
//

import UIKit
import WalletCoreKeeper

final class TonConnectCoordinator: Coordinator<Router<UIViewController>> {
  private let walletCoreAssembly: WalletCoreAssembly
  private let parameters: TonConnectParameters
  private let manifest: TonConnectManifest
  
  private var confirmationContinuation: CheckedContinuation<Bool, Never>?
  
  init(router: Router<UIViewController>,
       walletCoreAssembly: WalletCoreAssembly,
       parameters: TonConnectParameters,
       manifest: TonConnectManifest) {
    self.walletCoreAssembly = walletCoreAssembly
    self.parameters = parameters
    self.manifest = manifest
    super.init(router: router)
  }
  
  override func start() {
    openTonConnectPopup()
  }
}

private extension TonConnectCoordinator {
  func openTonConnectPopup() {
    let module = TonConnectPopupAssembly.module(
      tonConnectController: walletCoreAssembly.tonConnectController(
        parameters: parameters,
        manifest: manifest
      ),
      output: self
    )

    let modalCardContainerViewController = ModalCardContainerViewController(content: module.view)
    initialPresentable = modalCardContainerViewController
  }
}

// MARK: - TonConnectPopupModuleOutput

extension TonConnectCoordinator: TonConnectPopupModuleOutput {
  func tonConnectPopupModuleDidConnect(_ module: TonConnectPopupModuleInput) {
    initialPresentable?.dismiss(animated: true)
  }
  
  func tonConnectPopupModuleConfirmation(_ module: TonConnectPopupModuleInput) async -> Bool {
    return await withCheckedContinuation { [weak self] continuation in
      guard let self = self else { return }
      self.confirmationContinuation = continuation
      
      Task {
        await MainActor.run {
          let passcodeAssembly = PasscodeAssembly(walletCoreAssembly: self.walletCoreAssembly)
          let coordinator = passcodeAssembly.passcodeConfirmationCoordinator()
          coordinator.output = self
          
          self.addChild(coordinator)
          coordinator.start()
          self.initialPresentable?.present(coordinator.router.rootViewController, animated: true)
        }
      }
    }
  }
}

// MARK: - PasscodeConfirmationCoordinatorOutput

extension TonConnectCoordinator: PasscodeConfirmationCoordinatorOutput {
  func passcodeConfirmationCoordinatorDidConfirm(_ coordinator: PasscodeConfirmationCoordinator) {
    initialPresentable?.dismiss(animated: true)
    removeChild(coordinator)
    confirmationContinuation?.resume(returning: true)
    confirmationContinuation = nil
  }
  
  func passcodeConfirmationCoordinatorDidClose(_ coordinator: PasscodeConfirmationCoordinator) {
    initialPresentable?.dismiss(animated: true)
    removeChild(coordinator)
    confirmationContinuation?.resume(returning: false)
    confirmationContinuation = nil
  }
}
