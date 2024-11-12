import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore

public final class AddWalletCoordinator: RouterCoordinator<ViewControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didAddWallets: (() -> Void)?
  
  private var pairSignerCoordinator: PairSignerCoordinator?
  
  private let options: [AddWalletOption]
  private let walletAddController: WalletAddController
  private let createWalletCoordinatorProvider: (ViewControllerRouter) -> CreateWalletCoordinator
  private let importWalletCoordinatorProvider: (NavigationControllerRouter, _ isTestnet: Bool) -> ImportWalletCoordinator
  private let importWatchOnlyWalletCoordinatorProvider: (NavigationControllerRouter) -> ImportWatchOnlyWalletCoordinator
  private let pairSignerCoordinatorProvider: (NavigationControllerRouter) -> PairSignerCoordinator
  private let pairLedgerCoordinatorProvider: (ViewControllerRouter) -> PairLedgerCoordinator
  private let pairKeystoneCoordinatorProvider: (NavigationControllerRouter) -> PairKeystoneCoordinator
  
  init(router: ViewControllerRouter,
       options: [AddWalletOption],
       walletAddController: WalletAddController,
       createWalletCoordinatorProvider: @escaping (ViewControllerRouter) -> CreateWalletCoordinator,
       importWalletCoordinatorProvider: @escaping (NavigationControllerRouter, _ isTestnet: Bool) -> ImportWalletCoordinator,
       importWatchOnlyWalletCoordinatorProvider: @escaping (NavigationControllerRouter) -> ImportWatchOnlyWalletCoordinator,
       pairSignerCoordinatorProvider: @escaping (NavigationControllerRouter) -> PairSignerCoordinator,
       pairLedgerCoordinatorProvider: @escaping (ViewControllerRouter) -> PairLedgerCoordinator,
       pairKeystoneCoordinatorProvider:  @escaping (NavigationControllerRouter) -> PairKeystoneCoordinator) {
    self.walletAddController = walletAddController
    self.options = options
    self.createWalletCoordinatorProvider = createWalletCoordinatorProvider
    self.importWalletCoordinatorProvider = importWalletCoordinatorProvider
    self.importWatchOnlyWalletCoordinatorProvider = importWatchOnlyWalletCoordinatorProvider
    self.pairSignerCoordinatorProvider = pairSignerCoordinatorProvider
    self.pairLedgerCoordinatorProvider = pairLedgerCoordinatorProvider
    self.pairKeystoneCoordinatorProvider = pairKeystoneCoordinatorProvider
    super.init(router: router)
  }
  
  public override func start() {
    openAddWalletOptionPicker()
  }
  
  public override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
    guard let tonkeeperDeeplink = deeplink as? Deeplink else { return false }
    
    switch tonkeeperDeeplink {
    case .externalSign:
      guard let pairSignerCoordinator else { return false }
      return pairSignerCoordinator.handleDeeplink(deeplink: tonkeeperDeeplink)
    default:
      return false
    }
  }
}

private extension AddWalletCoordinator {
  func openAddWalletOptionPicker() {
    let module = AddWalletOptionPickerAssembly.module(
      options: options
    )
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    module.output.didSelectOption = { [weak self, unowned bottomSheetViewController] option in
      bottomSheetViewController.dismiss {
        self?.handleSelectedOption(option)
      }
    }
    
    bottomSheetViewController.didClose = { [weak self] interactivly in
      if interactivly {
        self?.didCancel?()
      }
    }
    
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func handleSelectedOption(_ option: AddWalletOption) {
    switch option {
    case .createRegular:
      openCreateRegularWallet(router: router)
    case .importRegular:
      openAddWallet(isTestnet: false)
    case .importWatchOnly:
      openAddWatchOnlyWallet()
    case .importTestnet:
      openAddWallet(isTestnet: true)
    case .signer:
      openPairSigner()
    case .keystone:
      openPairKeystone()
    case .ledger:
      openPairLedger()
    }
  }
  
  func openCreateRegularWallet(router: ViewControllerRouter) {
    let coordinator = createWalletCoordinatorProvider(
      router
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      self?.removeChild(coordinator)
      self?.didCancel?()
    }
    
    coordinator.didCreateWallet = { [weak self, weak coordinator] in
      self?.removeChild(coordinator)
      self?.didAddWallets?()
    }
    
    addChild(coordinator)
    coordinator.start()
  }

  func openAddWatchOnlyWallet() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    let router = NavigationControllerRouter(rootViewController: navigationController)
    
    let coordinator = importWatchOnlyWalletCoordinatorProvider(
      router
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      router.dismiss(animated: true) {
        self?.didCancel?()
      }
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didImportWallet = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      router.dismiss(animated: true) {
        self?.didAddWallets?()
      }
    }
    
    addChild(coordinator)
    coordinator.start()
    
    self.router.present(navigationController, onDismiss: { [weak self] in
      self?.didCancel?()
    })
  }

  func openAddWallet(isTestnet: Bool) {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    let router = NavigationControllerRouter(rootViewController: navigationController)
    
    let coordinator = importWalletCoordinatorProvider(
      router, isTestnet
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      self?.removeChild(coordinator)
      self?.router.dismiss(animated: true, completion: {
        self?.didCancel?()
      })
    }
    
    coordinator.didImportWallets = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      router.dismiss(animated: true) {
        self?.didAddWallets?()
      }
    }
    
    addChild(coordinator)
    coordinator.start()
    
    self.router.present(navigationController, onDismiss: { [weak self] in
      self?.didCancel?()
    })
  }
  
  func openPairKeystone() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    let router = NavigationControllerRouter(rootViewController: navigationController)
    
    let coordinator = pairKeystoneCoordinatorProvider(
      router
    )
    
    addChild(coordinator)
    coordinator.start()
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      self?.removeChild(coordinator)
      self?.router.dismiss(animated: true, completion: {
        self?.didCancel?()
      })
    }
    
    coordinator.didPaired = {[weak self, weak coordinator] in
      router.dismiss(animated: true) {
        self?.didAddWallets?()
      }
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    self.router.present(navigationController, onDismiss: { [weak self] in
      self?.didCancel?()
    })
  }
  
  func openPairSigner() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    let router = NavigationControllerRouter(rootViewController: navigationController)
    
    let coordinator = pairSignerCoordinatorProvider(
      router
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      router.dismiss(animated: true) {
        self?.didCancel?()
      }
      self?.pairSignerCoordinator = nil
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didPaired = {[weak self, weak coordinator] in
      router.dismiss(animated: true) {
        self?.didAddWallets?()
      }
      self?.pairSignerCoordinator = nil
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    self.pairSignerCoordinator = coordinator
    
    addChild(coordinator)
    coordinator.start()
    
    self.router.present(navigationController, onDismiss: { [weak self] in
      self?.didCancel?()
    })
  }
  
  func openPairLedger() {
    let coordinator = pairLedgerCoordinatorProvider(router)
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      self?.didCancel?()
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didPaired = {[weak self, weak coordinator] in
      self?.router.dismiss(animated: true) {
        self?.didAddWallets?()
      }
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
}
