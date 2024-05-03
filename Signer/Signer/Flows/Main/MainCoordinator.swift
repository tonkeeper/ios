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
    let module = ScannerAssembly.module(
      signerCoreAssembly: signerCoreAssembly,
      urlOpener: UIApplication.shared,
      title: "Scan QR Core",
      subtitle: "From Tonkeeper on the action confirmation page"
    )
    
    module.output.didScanDeeplink = { [weak self] deeplink in
      self?.router.dismiss(completion: {
        _ = self?.handleCoreDeeplink(deeplink)
      })
    }
    
    router.present(module.view)
  }
  
  func openAddWallet() {
    let addKeyViewController = AddKeyViewController()
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: addKeyViewController)
    
    addKeyViewController.didTapCreateNewKey = { [weak self, weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss(completion: {
        self?.openCreateKey()
      })
    }
    addKeyViewController.didTapImportKey = { [weak self, weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss(completion: {
        self?.openImportKey()
      })
    }
    
    bottomSheetViewController.present(fromViewController: router.rootViewController)
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
  
  func openSign() {
    let module = TonConnectConfirmationAssembly.module()
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    bottomSheetViewController.didClose = { [weak self] isInteractivly in
//      guard isInteractivly else { return }
////      keyWindow?.makeKeyAndVisible()
//      self?.didCancel?()
//      Task {
//        await tonConnectConfirmationController.cancel()
//      }
    }
    
//    module.output.didTapCancelButton = { [weak tonConnectConfirmationController, weak bottomSheetViewController] in
//      guard let tonConnectConfirmationController else { return }
//      Task {
//        await tonConnectConfirmationController.cancel()
//      }
//      bottomSheetViewController?.dismiss(completion: { [weak self] in
//        self?.didCancel?()
//      })
//    }
//    
//    module.output.didTapConfirmButton = { [weak self, weak bottomSheetViewController] in
//      guard let bottomSheetViewController, let self else { return false }
//      let isConfirmed = await self.openPasscodeConfirmation(fromViewController: bottomSheetViewController)
//      guard isConfirmed else { return false }
//      do {
//        try await self.tonConnectConfirmationController.confirm()
//        return true
//      } catch {
//        return false
//      }
//    }
//    
//    module.output.didConfirm = { [weak self, weak bottomSheetViewController] in
//      bottomSheetViewController?.dismiss(completion: { [weak self] in
//        self?.didConfirm?()
//      })
//    }
    
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func handleCoreDeeplink(_ deeplink: SignerCore.Deeplink) -> Bool {
    switch deeplink {
    case .tonsign(let tonsignDeeplink):
      switch tonsignDeeplink {
      case .plain: return true
      case .sign(let model):
        openSign()
        return true
      }
    }
  }
}
