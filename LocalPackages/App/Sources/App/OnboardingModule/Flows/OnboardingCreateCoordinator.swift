import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKScreenKit

public final class OnboardingCreateCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didCreateWallet: (() -> Void)?
  
  private let assembly: KeeperCore.OnboardingAssembly
  private let addWalletModule: AddWalletModule
  
  init(router: NavigationControllerRouter,
       assembly: KeeperCore.OnboardingAssembly) {
    self.assembly = assembly
    self.addWalletModule = AddWalletModule(
      dependencies: AddWalletModule.Dependencies(
        walletsUpdateAssembly: assembly.walletsUpdateAssembly
      )
    )
    super.init(router: router)
  }

  public override func start() {
    openCreatePasscode()
  }
}

private extension OnboardingCreateCoordinator {
  func openCreatePasscode() {
    let coordinator = PasscodeModule(
      dependencies: PasscodeModule.Dependencies(
        passcodeAssembly: assembly.passcodeAssembly
      )
    ).createCreatePasscodeCoordinator(router: router)
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      self?.didCancel?()
    }
    
    coordinator.didCreatePasscode = { [weak self] passcode in
      self?.openCustomizeWallet(passcode: passcode)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openCustomizeWallet(passcode: String) {
    let module = addWalletModule.createCustomizeWalletModule(
      configurator: AddWalletCustomizeWalletViewModelConfigurator()
    )
    
    module.output.didCustomizeWallet = { [weak self] model in
      self?.createWallet(model: model, passcode: passcode)
    }
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
  
  func createWallet(model: CustomizeWalletModel, passcode: String) {
    let createPasscodeController = assembly.passcodeAssembly.passcodeCreateController()
    let addController = assembly.walletsUpdateAssembly.walletAddController()
    let metaData = WalletMetaData(
      label: model.name,
      tintColor: model.tintColor,
      emoji: model.emoji)
    do {
      try createPasscodeController.createPasscode(passcode)
      try addController.createWallet(metaData: metaData)
      didCreateWallet?()
    } catch {
      print("Log: Wallet creation failed, error \(error)")
    }
  }
}
