import UIKit
import TKUIKit
import SignerCore

final class MainCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  private let signerCoreAssembly: SignerCore.Assembly
  
  init(router: NavigationControllerRouter,
       signerCoreAssembly: SignerCore.Assembly) {
    self.signerCoreAssembly = signerCoreAssembly
    super.init(router: router)
  }

  override func start() {
    openMain()
  }
}

private extension MainCoordinator {
  func openMain() {
    let module = MainModuleAssembly.module(signerCoreAssembly: signerCoreAssembly)
    
    module.output.didTapAddWallet = { [weak self] in
      self?.openAddWallet()
    }
    
    module.output.didTapScanButton = { [weak self] in
      self?.openScan()
    }
    
    module.output.didTapSettings = { [weak self] in
      self?.openSettings()
    }
    
    module.output.didSelectKey = { [weak self] walletKey in
      self?.openKeyDetails(walletKey: walletKey)
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openScan() {
    print("scan")
  }
  
  func openAddWallet() {
    let addKeyViewController = AddKeyViewController()
    addKeyViewController.didTapCreateNewKey = { [weak self, weak addKeyViewController] in
      addKeyViewController?.dismiss(animated: true, completion: {
        self?.openCreateKey()
      })
    }
    addKeyViewController.didTapImportKey = { [weak self, weak addKeyViewController] in
      addKeyViewController?.dismiss(animated: true, completion: {
        self?.openImportKey()
      })
      
    }
    let pullableCardViewController = TKPullableCardContainerViewController(content: addKeyViewController)
    router.present(pullableCardViewController)
  }
  
  func openSettings() {
    let coordinator = SettingsCoordinator(router: router, signerCoreAssembly: signerCoreAssembly)
    coordinator.didFinish = { [weak self, unowned coordinator] in
      self?.removeChild(coordinator)
    }
    addChild(coordinator)
    coordinator.start()
  }
  
  func openKeyDetails(walletKey: WalletKey) {
    let keyDetailsCoordinator = KeyDetailsCoordinator(
      router: router,
      signerCoreAssembly: signerCoreAssembly,
      walletKey: walletKey
    )
    keyDetailsCoordinator.didFinish = { [weak self, unowned keyDetailsCoordinator] in
      self?.removeChild(keyDetailsCoordinator)
    }
    
    addChild(keyDetailsCoordinator)
    keyDetailsCoordinator.start()
  }
  
  func openCreateKey() {
    let navigationController = NavigationController()
    navigationController.configureTransparentAppearance()
    
    let createKeyCoordinator = CreateKeyCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      assembly: signerCoreAssembly
    )
    createKeyCoordinator.didFinish = { [weak self, unowned createKeyCoordinator] in
      navigationController.dismiss(animated: true) {
        self?.removeChild(createKeyCoordinator)
      }
    }
    createKeyCoordinator.didCreateKey = { [weak self, unowned createKeyCoordinator] in
      navigationController.dismiss(animated: true) {
        self?.removeChild(createKeyCoordinator)
      }
    }
    
    addChild(createKeyCoordinator)
    createKeyCoordinator.start()
    
    router.present(navigationController)
  }
  
  func openImportKey() {
    let navigationController = NavigationController()
    navigationController.configureTransparentAppearance()
    
    let createKeyCoordinator = ImportKeyCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      assembly: signerCoreAssembly
    )
    createKeyCoordinator.didFinish = { [weak self, unowned createKeyCoordinator] in
      navigationController.dismiss(animated: true) {
        self?.removeChild(createKeyCoordinator)
      }
    }
    createKeyCoordinator.didImportKey = { [weak self, unowned createKeyCoordinator] in
      navigationController.dismiss(animated: true) {
        self?.removeChild(createKeyCoordinator)
      }
    }
    
    addChild(createKeyCoordinator)
    createKeyCoordinator.start()
    
    router.present(navigationController)
  }
}
