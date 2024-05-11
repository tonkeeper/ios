import UIKit
import TKCoordinator
import SignerCore

final class SettingsCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  
  private let signerCoreAssembly: SignerCore.Assembly
  
  init(router: NavigationControllerRouter,
       signerCoreAssembly: SignerCore.Assembly) {
    self.signerCoreAssembly = signerCoreAssembly
    super.init(router: router)
  }

  override func start() {
    openSettings()
  }
}

private extension SettingsCoordinator {
  func openSettings() {
    let module = SettingsModuleAssembly.module(urlOpener: UIApplication.shared)
    module.view.setupBackButton()
    
    module.output.didTapChangePassword = { [weak self] in
      self?.openChangePassword()
    }
    
    router.push(
      viewController: module.view,
      onPopClosures: { [weak self] in
        self?.didFinish?()
      })
  }
  
  func openChangePassword() {
    let navigationController = NavigationController()
    navigationController.configureTransparentAppearance()
    
    let coordinator = ChangePasswordCoordinator(
      router: NavigationControllerRouter(
        rootViewController: navigationController
      ),
      assembly: signerCoreAssembly
    )
    
    coordinator.didFinish = { [weak self, unowned coordinator] in
      self?.router.dismiss {
        self?.removeChild(coordinator)
      }
    }
    
    addChild(coordinator)
    coordinator.start()
    
    navigationController.modalPresentationStyle = .fullScreen
    router.present(navigationController)
  }
}
