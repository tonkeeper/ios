import UIKit
import KeeperCore
import TKCore
import TKCoordinator
import TKUIKit
import TKScreenKit

public final class OnboardingImportCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didImportWallets: (() -> Void)?
  
  private let coreAssembly: TKCore.CoreAssembly
  private let assembly: KeeperCore.OnboardingAssembly
  private let addWalletModule: AddWalletModule
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       assembly: KeeperCore.OnboardingAssembly) {
    self.coreAssembly = coreAssembly
    self.assembly = assembly
    self.addWalletModule = AddWalletModule(
      dependencies: AddWalletModule.Dependencies(
        walletsUpdateAssembly: assembly.walletsUpdateAssembly,
        coreAssembly: coreAssembly,
        scannerAssembly: assembly.scannerAssembly()
      )
    )
    super.init(router: router)
  }

  public override func start() {
    openInputRecoveryPhrase()
  }
}

private extension OnboardingImportCoordinator {
  func openInputRecoveryPhrase() {
    let coordinator = addWalletModule.createRecoveryPhraseCoordinator(router: router)
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      self?.didCancel?()
    }
    
    coordinator.didImportWallets = { [weak self] phrase, revisions in
      self?.openCreatePasscode(phrase: phrase, revisions: revisions)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openCreatePasscode(phrase: [String], revisions: [WalletContractVersion]) {
    let coordinator = PasscodeModule(
      dependencies: PasscodeModule.Dependencies(passcodeAssembly: assembly.passcodeAssembly)
    ).createCreatePasscodeCoordinator(router: router)
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didCreatePasscode = { [weak self] passcode in
      self?.openCustomizeWallet(phrase: phrase, revisions: revisions, passcode: passcode)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openCustomizeWallet(phrase: [String], revisions: [WalletContractVersion], passcode: String) {
    let module = addWalletModule.createCustomizeWalletModule(configurator: AddWalletCustomizeWalletViewModelConfigurator())
    
    module.output.didCustomizeWallet = { [weak self] model in
      self?.importWallet(phrase: phrase, revisions: revisions, passcode: passcode, model: model)
    }
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
  
  func importWallet(phrase: [String],
                    revisions: [WalletContractVersion],
                    passcode: String,
                    model: CustomizeWalletModel) {
    let createPasscodeController = assembly.passcodeAssembly.passcodeCreateController()
    let addController = assembly.walletsUpdateAssembly.walletAddController()
    let metaData = WalletMetaData(
      label: model.name,
      tintColor: model.tintColor,
      emoji: model.emoji)
    do {
      try createPasscodeController.createPasscode(passcode)
      try addController.importWallets(
        phrase: phrase,
        revisions: revisions,
        metaData: metaData)
      didImportWallets?()
    } catch {
      print("Log: Wallet import failed, error \(error)")
    }
  }
}
