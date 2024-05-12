import UIKit
import TKUIKit
import TKCoordinator
import SignerCore
import SignerLocalize
import TonSwift
import CoreComponents

final class MainCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  private let signerCoreAssembly: SignerCore.Assembly
  private let mainController: MainController
  
  init(router: NavigationControllerRouter,
       signerCoreAssembly: SignerCore.Assembly) {
    self.signerCoreAssembly = signerCoreAssembly
    self.mainController = signerCoreAssembly.mainController()
    super.init(router: router)
  }

  override func start(deeplink: (any CoordinatorDeeplink)? = nil) {
    openMain()
    DispatchQueue.main.async {
      _ = self.handleDeeplink(deeplink: deeplink)
    }
  }
  
  override func handleDeeplink(deeplink: (any CoordinatorDeeplink)?) -> Bool {
    if let coreDeeplink = deeplink as? SignerCore.Deeplink {
      return handleCoreDeeplink(coreDeeplink, scanner: false)
    } else if let appDeeplink = deeplink as? AppDeeplink {
      switch appDeeplink {
      case .scan:
        openScan(animated: true)
        return true
      }
    } else {
      do {
        let deeplink = try mainController.parseDeeplink(deeplink: deeplink?.string)
        return handleCoreDeeplink(deeplink, scanner: false)
      } catch {
        return false
      }
    }
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
  
  func openScan(animated: Bool = true) {
    let module = ScannerAssembly.module(
      signerCoreAssembly: signerCoreAssembly,
      urlOpener: UIApplication.shared,
      title: SignerLocalize.Scanner.title,
      subtitle: SignerLocalize.Scanner.caption
    )
    module.output.didScanDeeplink = { [weak self] deeplink in
      self?.router.dismiss(completion: {
        _ = self?.handleCoreDeeplink(deeplink, scanner: true)
      })
    }
    
    let navigationController = TKNavigationController(rootViewController: module.view)
    navigationController.configureTransparentAppearance()
    
    router.present(navigationController, animated: animated)
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
  
  func openSign(model: TonSignModel, walletKey: WalletKey, scanner: Bool) {
    guard let windowScene = UIApplication.keyWindowScene else { return }
    let window = TKWindow(windowScene: windowScene)
    window.applyThemeMode(.blue)
    
    let coordinator = SignCoordinator(
      router: WindowRouter(
        window: window
      ),
      model: model,
      walletKey: walletKey,
      scanner: scanner,
      signerCoreAssembly: signerCoreAssembly
    )
    
    coordinator.didCancel = { [weak coordinator, weak self] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func handleCoreDeeplink(_ deeplink: SignerCore.Deeplink, scanner: Bool) -> Bool {
    switch deeplink {
    case .tonsign(let tonsignDeeplink):
      switch tonsignDeeplink {
      case .plain: return true
      case .sign(let model):
        guard let walletKey = signerCoreAssembly
          .storesAssembly
          .walletKeysStore
          .getWalletKeys().first(where: { $0.publicKey.data == model.publicKey.data }) else {
          return false
        }
        
        openSign(model: model, walletKey: walletKey, scanner: scanner)
        return true
      }
    }
  }
}
