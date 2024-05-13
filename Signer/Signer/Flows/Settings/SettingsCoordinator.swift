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
    let itemsProvider = SettingsRootItemsProvider(urlOpener: UIApplication.shared)
    itemsProvider.didTapChangePassword = { [weak self] in
      self?.openChangePassword()
    }
    itemsProvider.didTapLegal = { [weak self] in
      self?.openLegal()
    }
    let module = SettingsModuleAssembly.module(itemsProvider: itemsProvider)
    module.view.setupBackButton()
    
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
  
  func openLegal() {
    let itemsProvider = SettingsLegalItemsProvider(urlOpener: UIApplication.shared)
    itemsProvider.didSelectFontLicense = { [weak self] in
      let viewController = FontLicenseViewController()
      viewController.setupBackButton()
      self?.router.rootViewController.pushViewController(viewController, animated: true)
    }
    
    let module = SettingsModuleAssembly.module(itemsProvider: itemsProvider)
    module.view.setupBackButton()
    
    router.push(
      viewController: module.view)
  }
}
