import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore

public final class AddWalletCoordinator: RouterCoordinator<ViewControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didAddWallets: (() -> Void)?
  
  private var pairSignerCoordinator: PairSignerCoordinator?
  
  private let walletAddController: WalletAddController
  private let createWalletCoordinatorProvider: (NavigationControllerRouter) -> CreateWalletCoordinator
  private let importWalletCoordinatorProvider: (NavigationControllerRouter) -> ImportWalletCoordinator
  private let importWatchOnlyWalletCoordinatorProvider: (NavigationControllerRouter) -> ImportWatchOnlyWalletCoordinator
  private let pairSignerCoordinatorProvider: (NavigationControllerRouter) -> PairSignerCoordinator
  
  init(router: ViewControllerRouter,
       walletAddController: WalletAddController,
       createWalletCoordinatorProvider: @escaping (NavigationControllerRouter) -> CreateWalletCoordinator,
       importWalletCoordinatorProvider: @escaping (NavigationControllerRouter) -> ImportWalletCoordinator,
       importWatchOnlyWalletCoordinatorProvider: @escaping (NavigationControllerRouter) -> ImportWatchOnlyWalletCoordinator,
       pairSignerCoordinatorProvider: @escaping (NavigationControllerRouter) -> PairSignerCoordinator) {
    self.walletAddController = walletAddController
    self.createWalletCoordinatorProvider = createWalletCoordinatorProvider
    self.importWalletCoordinatorProvider = importWalletCoordinatorProvider
    self.importWatchOnlyWalletCoordinatorProvider = importWatchOnlyWalletCoordinatorProvider
    self.pairSignerCoordinatorProvider = pairSignerCoordinatorProvider
    super.init(router: router)
  }
  
  public override func start() {
    openAddWalletOptionPicker()
  }
  
  public override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
    guard let tonkeeperDeeplink = deeplink as? TonkeeperDeeplink else { return false }
    
    switch tonkeeperDeeplink {
    case .signer(let signerDeeplink):
      guard let pairSignerCoordinator else { return false }
      return pairSignerCoordinator.handleDeeplink(deeplink: signerDeeplink)
    }
  }
}

private extension AddWalletCoordinator {
  func openAddWalletOptionPicker() {
    let module = AddWalletOptionPickerAssembly.module(
      options: [
        .createRegular,
        .importRegular,
        .importWatchOnly,
        .signer
      ]
    )
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    module.output.didSelectOption = { [weak self, unowned bottomSheetViewController] option in
      bottomSheetViewController.dismiss {
        switch option {
        case .createRegular: self?.openCreateRegularWallet()
        case .importRegular: self?.openAddRegularWallet()
        case .importWatchOnly: self?.openAddWatchOnlyWallet()
        case .importTestnet: break
        case .signer: self?.openPairSigner()
        }
      }
    }
    
    bottomSheetViewController.didClose = { [weak self] interactivly in
      if interactivly {
        self?.didCancel?()
      }
    }
    
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func openCreateRegularWallet() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let coordinator = createWalletCoordinatorProvider(
      NavigationControllerRouter(rootViewController: navigationController)
    )
    
    coordinator.didCancel = { [weak self, weak coordinator, weak navigationController] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      navigationController?.dismiss(animated: true, completion: {
        self?.didCancel?()
      })
    }
    
    coordinator.didCreateWallet = { [weak self, weak coordinator, weak navigationController] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      navigationController?.dismiss(animated: true, completion: {
        self?.didAddWallets?()
      })
    }
    
    addChild(coordinator)
    coordinator.start()
    
    router.present(navigationController, onDismiss: { [weak self] in
      self?.didCancel?()
    })
  }
  
  func openAddRegularWallet() {
    openAddWallet()
  }
  
  func openAddWatchOnlyWallet() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let coordinator = importWatchOnlyWalletCoordinatorProvider(
      NavigationControllerRouter(rootViewController: navigationController)
    )
    
    coordinator.didCancel = { [weak self, weak coordinator, weak navigationController] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      navigationController?.dismiss(animated: true, completion: {
        self?.didCancel?()
      })
    }
    
    coordinator.didImportWallet = { [weak self, weak coordinator, weak navigationController] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      navigationController?.dismiss(animated: true, completion: {
        self?.didAddWallets?()
      })
    }
    
    addChild(coordinator)
    coordinator.start()
    
    router.present(navigationController, onDismiss: { [weak self] in
      self?.didCancel?()
    })
  }

  func openAddWallet() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let coordinator = importWalletCoordinatorProvider(
      NavigationControllerRouter(rootViewController: navigationController)
    )
    
    coordinator.didCancel = { [weak self, weak coordinator, weak navigationController] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      navigationController?.dismiss(animated: true)
      self?.didCancel?()
    }
    
    coordinator.didImportWallets = { [weak self, weak coordinator, weak navigationController] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      navigationController?.dismiss(animated: true)
      self?.didAddWallets?()
    }
    
    addChild(coordinator)
    coordinator.start()
    
    router.present(navigationController, onDismiss: { [weak self] in
      self?.didCancel?()
    })
  }
  
  func openPairSigner() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let coordinator = pairSignerCoordinatorProvider(
      NavigationControllerRouter(rootViewController: navigationController)
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      navigationController.dismiss(animated: true)
      self?.didAddWallets?()
      self?.pairSignerCoordinator = nil
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didPaired = {[weak self, weak coordinator] in
      navigationController.dismiss(animated: true)
      self?.didAddWallets?()
      self?.pairSignerCoordinator = nil
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    self.pairSignerCoordinator = coordinator
    
    addChild(coordinator)
    coordinator.start()
    
    router.present(navigationController, onDismiss: { [weak self] in
      self?.didCancel?()
    })
  }
}
