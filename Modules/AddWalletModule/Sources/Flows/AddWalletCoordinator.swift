import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore

public final class AddWalletCoordinator: RouterCoordinator<ViewControllerRouter> {
  
  public var didFinish: (() -> Void)?
  
  private let walletAddController: WalletAddController
  private let createWalletCoordinatorProvider: (NavigationControllerRouter) -> CreateWalletCoordinator
  private let importWalletCoordinatorProvider: (NavigationControllerRouter) -> ImportWalletCoordinator
  
  init(router: ViewControllerRouter,
       walletAddController: WalletAddController,
       createWalletCoordinatorProvider: @escaping (NavigationControllerRouter) -> CreateWalletCoordinator,
       importWalletCoordinatorProvider: @escaping (NavigationControllerRouter) -> ImportWalletCoordinator) {
    self.walletAddController = walletAddController
    self.createWalletCoordinatorProvider = createWalletCoordinatorProvider
    self.importWalletCoordinatorProvider = importWalletCoordinatorProvider
    super.init(router: router)
  }
  
  public override func start() {
    openAddWalletOptionPicker()
  }
}

private extension AddWalletCoordinator {
  func openAddWalletOptionPicker() {
    let module = AddWalletOptionPickerAssembly.module(options: [.createRegular, .importRegular, .importTestnet])
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    module.output.didSelectOption = { [weak self, unowned bottomSheetViewController] option in
      bottomSheetViewController.dismiss {
        switch option {
        case .createRegular: self?.openCreateRegularWallet()
        case .importRegular: self?.openAddRegularWallet()
        case .importTestnet: self?.openAddTestnetWallet()
        }
      }
    }
    
    bottomSheetViewController.didClose = { [weak self] _ in
      self?.didFinish?()
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
      navigationController?.dismiss(animated: true)
      self?.didFinish?()
    }
    
    coordinator.didCreateWallet = { [weak self, weak coordinator, weak navigationController] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      navigationController?.dismiss(animated: true)
      self?.didFinish?()
    }
    
    addChild(coordinator)
    coordinator.start()
    
    router.present(navigationController)
  }
  
  func openAddRegularWallet() {
    openAddWallet(isTestnet: false)
  }
  
  func openAddTestnetWallet() {
    openAddWallet(isTestnet: true)
  }
  
  func openAddWallet(isTestnet: Bool) {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    navigationController.isModalInPresentation = true
    
    let coordinator = importWalletCoordinatorProvider(
      NavigationControllerRouter(rootViewController: navigationController)
    )
    
    coordinator.didCancel = { [weak self, weak coordinator, weak navigationController] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      navigationController?.dismiss(animated: true)
      self?.didFinish?()
    }
    
//    coordinator.didImportWallet = { [weak self, weak coordinator, weak navigationController] phrase, model in
//      guard let coordinator = coordinator else { return }
//      self?.removeChild(coordinator)
//      self?.importWallet(phrase: phrase, model: model, isTestnet: isTestnet)
//      navigationController?.dismiss(animated: true)
//    }
    
    addChild(coordinator)
    coordinator.start()
    
    router.present(navigationController)
  }
  
  func createWallet(model: CustomizeWalletModel) {
//    let metaData = WalletMetaData(
//      label: model.name,
//      colorIdentifier: model.colorIdentifier,
//      emoji: model.emoji)
//    do {
//      try walletAddController.createWallet(metaData: metaData)
//      didFinish?()
//    } catch {
//      print("Log: Wallet creation failed")
//    }
  }
  
  func importWallet(phrase: [String], model: CustomizeWalletModel, isTestnet: Bool) {
//    let metaData = WalletMetaData(
//      label: model.name,
//      colorIdentifier: model.colorIdentifier,
//      emoji: model.emoji)
//    do {
//      try walletAddController.addWallet(phrase: phrase, metaData: metaData, isTestnet: isTestnet)
//      didFinish?()
//    } catch {
//      print("Log: Wallet import failed")
//    }
  }
}
