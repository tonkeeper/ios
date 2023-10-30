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
  
  init(router: Router<UIViewController>,
       tonConnectConfirmationController: TonConnectConfirmationController) {
    self.tonConnectConfirmationController = tonConnectConfirmationController
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
  func showConfirmation() {
    guard let windowScene = UIApplication.keyWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = router.rootViewController
    window.makeKeyAndVisible()
    self.window = window
    
    let module = TonConnectConfirmationAssembly.module(output: self)
    let container = ModalCardContainerViewController(content: module.view)
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
}

// MARK: - TonConnectConfirmationControllerOutput

extension TonConnectConfirmationCoordinator: TonConnectConfirmationControllerOutput {
  func tonConnectConfirmationControllerDidStartEmulation(_ controller: WalletCore.TonConnectConfirmationController) {
    ToastController.showToast(configuration: .loading)
  }
  
  func tonConnectConfirmationControllerDidFinishEmulation(_ controller: WalletCore.TonConnectConfirmationController, result: Result<Void, Error>) {
    switch result {
    case .success(let success):
      ToastController.hideToast()
      showConfirmation()
    case .failure:
      ToastController.showToast(configuration: .failed)
    }
  }
}
