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
  private let createWalletCoordinatorProvider: (NavigationControllerRouter) -> CreateWalletCoordinator
  private let importWalletCoordinatorProvider: (NavigationControllerRouter) -> ImportWalletCoordinator
  private let importWatchOnlyWalletCoordinatorProvider: (NavigationControllerRouter) -> ImportWatchOnlyWalletCoordinator
  private let pairSignerCoordinatorProvider: (NavigationControllerRouter) -> PairSignerCoordinator
  private let createPasscodeCoordinatorProvider: ((NavigationControllerRouter) -> CreatePasscodeCoordinator)?
  
  init(router: ViewControllerRouter,
       options: [AddWalletOption],
       walletAddController: WalletAddController,
       createWalletCoordinatorProvider: @escaping (NavigationControllerRouter) -> CreateWalletCoordinator,
       importWalletCoordinatorProvider: @escaping (NavigationControllerRouter) -> ImportWalletCoordinator,
       importWatchOnlyWalletCoordinatorProvider: @escaping (NavigationControllerRouter) -> ImportWatchOnlyWalletCoordinator,
       pairSignerCoordinatorProvider: @escaping (NavigationControllerRouter) -> PairSignerCoordinator,
       createPasscodeCoordinatorProvider: ((NavigationControllerRouter) -> CreatePasscodeCoordinator)?) {
    self.walletAddController = walletAddController
    self.options = options
    self.createWalletCoordinatorProvider = createWalletCoordinatorProvider
    self.importWalletCoordinatorProvider = importWalletCoordinatorProvider
    self.importWatchOnlyWalletCoordinatorProvider = importWatchOnlyWalletCoordinatorProvider
    self.pairSignerCoordinatorProvider = pairSignerCoordinatorProvider
    self.createPasscodeCoordinatorProvider = createPasscodeCoordinatorProvider
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
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    let router = NavigationControllerRouter(rootViewController: navigationController)
    
    if let createPasscodeCoordinator = createPasscodeCoordinatorProvider?(router) {
      createPasscodeCoordinator.didCreatePasscode = { [weak self] passcode in
        self?.openOption(option: option, passcode: passcode, router: router)
      }
      
      createPasscodeCoordinator.didCancel = { [weak self, weak createPasscodeCoordinator] in
        navigationController.dismiss(animated: true) {
          self?.didCancel?()
        }
        guard let coordinator = createPasscodeCoordinator else { return }
        self?.removeChild(coordinator)
      }
      
      addChild(createPasscodeCoordinator)
      createPasscodeCoordinator.start()
      self.router.present(navigationController, onDismiss: { [weak self, weak createPasscodeCoordinator] in
        self?.didCancel?()
        guard let coordinator = createPasscodeCoordinator else { return }
        self?.removeChild(coordinator)
      })
    } else {
      openOption(option: option, passcode: nil, router: router)
      self.router.present(navigationController, onDismiss: { [weak self] in
        self?.didCancel?()
      })
    }
  }
  
  func openOption(option: AddWalletOption, passcode: String?, router: NavigationControllerRouter) {
    switch option {
    case .createRegular:
      break
    case .importRegular:
      openAddWallet(router: router, passcode: passcode)
    case .importWatchOnly:
      openAddWatchOnlyWallet(router: router, passcode: passcode)
    case .importTestnet:
      break
    case .signer:
      openPairSigner(router: router, passcode: passcode)
    }
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

  func openAddWatchOnlyWallet(router: NavigationControllerRouter, passcode: String?) {
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
  }

  func openAddWallet(router: NavigationControllerRouter, passcode: String?) {
    let coordinator = importWalletCoordinatorProvider(
      router
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      self?.didCancel?()
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
  }
  
  func openPairSigner(router: NavigationControllerRouter, passcode: String?) {
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
  }
}
