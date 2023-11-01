//
//  TonConnectConfirmationCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 27.10.2023.
//

import UIKit
import WalletCore

protocol TonConnectConfirmationCoordinatorOutput: AnyObject {
  func tonConnectConfirmationCoordinatorDidFinish(_ coordinator: TonConnectConfirmationCoordinator)
}

final class TonConnectConfirmationCoordinator: Coordinator<Router<UIViewController>> {
  weak var output: TonConnectConfirmationCoordinatorOutput?
  
  private var window: UIWindow?
  private let tonConnectConfirmationController: TonConnectConfirmationController
  private let walletCoreAssembly: WalletCoreAssembly
  
  private var confirmationContinuation: CheckedContinuation<Bool, Never>?
  
  init(router: Router<UIViewController>,
       tonConnectConfirmationController: TonConnectConfirmationController,
       walletCoreAssembly: WalletCoreAssembly) {
    self.tonConnectConfirmationController = tonConnectConfirmationController
    self.walletCoreAssembly = walletCoreAssembly
    super.init(router: router)
  }
  
  override func start() {}
  
  func handleAppRequest(_ appRequest: WalletCore.TonConnect.AppRequest,
                     app: TonConnectApp) {
    tonConnectConfirmationController.handleAppRequest(
      appRequest,
      app: app
    )
  }
}

private extension TonConnectConfirmationCoordinator {
  func showConfirmation(model: TonConnectConfirmationModel) {
    guard let windowScene = UIApplication.keyWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = router.rootViewController
    window.makeKeyAndVisible()
    self.window = window
    
    let module = TonConnectConfirmationAssembly.module(
      model: model,
      output: self
    )
    let container = ModalCardContainerViewController(content: module.view)
    container.headerSize = .big
    let modalCardRouter = Router(rootViewController: container)
    
    router.present(modalCardRouter.rootViewController, dismiss: { [weak self] in
      guard let self = self else { return }
      self.window = nil
      self.tonConnectConfirmationController.didFinish()
    })
  }
}

// MARK: - TonConnectConfirmationModuleOutput

extension TonConnectConfirmationCoordinator: TonConnectConfirmationModuleOutput {
  func tonConnectConfirmationModuleDidConfirm(_ module: TonConnectConfirmationModuleInput) async throws {
    return try await tonConnectConfirmationController.confirmTransaction()
  }
  
  func tonConnectConfirmationModuleDidFinish(_ module: TonConnectConfirmationModuleInput) {
    router.dismiss()
  }
  
  func tonConnectConfirmationModuleDidCancel(_ module: TonConnectConfirmationModuleInput) {
    router.dismiss()
  }
  
  func tonConnectConfirmationModuleUserConfirmation(_ module: TonConnectConfirmationModuleInput) async -> Bool {
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
          self.window?.rootViewController?.presentedViewController?.present(coordinator.router.rootViewController, animated: true)
        }
      }
    }
  }
}

// MARK: - TonConnectConfirmationControllerOutput

extension TonConnectConfirmationCoordinator: TonConnectConfirmationControllerOutput {
  func tonConnectConfirmationControllerDidStartEmulation(_ controller: WalletCore.TonConnectConfirmationController) {
    ToastController.showToast(configuration: .loading)
  }
  
  func tonConnectConfirmationControllerDidFinishEmulation(_ controller: WalletCore.TonConnectConfirmationController, result: Result<TonConnectConfirmationModel, Error>) {
    switch result {
    case .success(let success):
      ToastController.hideToast()
      showConfirmation(model: success)
    case .failure:
      ToastController.hideToast()
      ToastController.showToast(configuration: .failed)
    }
  }
}

// MARK: - PasscodeConfirmationCoordinatorOutput

extension TonConnectConfirmationCoordinator: PasscodeConfirmationCoordinatorOutput {
  func passcodeConfirmationCoordinatorDidConfirm(_ coordinator: PasscodeConfirmationCoordinator) {
    window?.rootViewController?.presentedViewController?.dismiss(animated: true)
    removeChild(coordinator)
    confirmationContinuation?.resume(returning: true)
    confirmationContinuation = nil
  }
  
  func passcodeConfirmationCoordinatorDidClose(_ coordinator: PasscodeConfirmationCoordinator) {
    window?.rootViewController?.presentedViewController?.dismiss(animated: true)
    removeChild(coordinator)
    confirmationContinuation?.resume(returning: false)
    confirmationContinuation = nil
  }
}
