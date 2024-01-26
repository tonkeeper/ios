import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKScreenKit
import PasscodeModule
import AddWalletModule

public final class OnboardingImportCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didImportWallets: (() -> Void)?
  
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
    let coordinator = PasscodeModule().createCreatePasscodeCoordinator(router: router)
    
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
    let module = addWalletModule.createCustomizeWalletModule()
    
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
    
    let addController = assembly.walletsUpdateAssembly.walletAddController()
    let metaData = WalletMetaData(
      label: model.name,
      colorIdentifier: model.colorIdentifier,
      emoji: model.emoji)
    do {
      try addController.importWallets(
        phrase: phrase,
        revisions: revisions,
        metaData: metaData)
      didImportWallets?()
    } catch {
      print("Log: Wallet import failed")
    }
  }
}
