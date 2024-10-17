import UIKit
import KeeperCore
import TonSwift
import TKCore
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKLocalize

final class ImportWalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didCancel: (() -> Void)?
  var didImportWallets: (() -> Void)?
  
  private let isTestnet: Bool
  private let analyticsProvider: AnalyticsProvider
  private let walletsUpdateAssembly: WalletsUpdateAssembly
  private let storesAssembly: StoresAssembly
  private let customizeWalletModule: () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>
  
  init(router: NavigationControllerRouter,
       analyticsProvider: AnalyticsProvider,
       walletsUpdateAssembly: WalletsUpdateAssembly,
       storesAssembly: StoresAssembly,
       isTestnet: Bool,
       customizeWalletModule: @escaping () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>) {
    self.analyticsProvider = analyticsProvider
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.storesAssembly = storesAssembly
    self.isTestnet = isTestnet
    self.customizeWalletModule = customizeWalletModule
    super.init(router: router)
  }
  
  override func start() {
    openRecoveryPhraseInput()
  }
}

private extension ImportWalletCoordinator {
  func openRecoveryPhraseInput() {
    let inputRecoveryPhrase = TKInputRecoveryPhraseAssembly.module(
      title: TKLocales.ImportWallet.title,
      caption: TKLocales.ImportWallet.description,
      continueButtonTitle: TKLocales.Actions.continueAction,
      pasteButtonTitle: TKLocales.Actions.paste,
      validator: AddWalletInputRecoveryPhraseValidator(),
      suggestsProvider: AddWalletInputRecoveryPhraseSuggestsProvider()
    )
    
    inputRecoveryPhrase.output.didInputRecoveryPhrase = { [weak self] phrase, completion in
      guard let self = self else { return }
      self.detectActiveWallets(phrase: phrase, completion: completion)
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      inputRecoveryPhrase.viewController.setupLeftCloseButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      inputRecoveryPhrase.viewController.setupBackButton()
    }
    
    router.push(
      viewController: inputRecoveryPhrase.viewController,
      animated: true,
      onPopClosures: { [weak self] in
        self?.didCancel?()
      },
      completion: nil)
  }
  
  func detectActiveWallets(phrase: [String], completion: @escaping () -> Void) {
    Task {
      do {
        let activeWallets = try await walletsUpdateAssembly.walletImportController().findActiveWallets(
          phrase: phrase,
          isTestnet: isTestnet
        )
        await MainActor.run {
          completion()
          handleActiveWallets(phrase: phrase, activeWalletModels: activeWallets)
        }
      } catch {
        await MainActor.run {
          completion()
        }
      }
    }
  }
  
  func handleActiveWallets(phrase: [String], activeWalletModels: [ActiveWalletModel]) {
    if activeWalletModels.count == 1, activeWalletModels[0].revision == WalletContractVersion.currentVersion {
      handleDidChooseRevisions(phrase: phrase, revisions: [WalletContractVersion.currentVersion])
    } else {
      openChooseWalletToAdd(phrase: phrase, activeWalletModels: activeWalletModels)
    }
  }
  
  func openChooseWalletToAdd(phrase: [String], activeWalletModels: [ActiveWalletModel]) {
    let module = ChooseWalletToAddAssembly.module(
      activeWalletModels: activeWalletModels,
      configuration: ChooseWalletToAddConfiguration(
        showRevision: true,
        selectLastRevision: true
      ),
      amountFormatter: walletsUpdateAssembly.formattersAssembly.amountFormatter,
      isTestnet: isTestnet
    )
    
    module.output.didSelectWallets = { [weak self] wallets in
      let revisions = wallets.map { $0.revision }
      self?.handleDidChooseRevisions(phrase: phrase, revisions: revisions)
    }
    
    module.view.setupBackButton()
    
    router.push(
      viewController: module.view,
      animated: true,
      onPopClosures: {},
      completion: nil)
  }
  
  func handleDidChooseRevisions(phrase: [String], revisions: [WalletContractVersion]) {
    let hasMnemonics = walletsUpdateAssembly.repositoriesAssembly.mnemonicsRepository().hasMnemonics()
    let hasRegularWallet = { [walletsUpdateAssembly] in
      do {
        return try walletsUpdateAssembly.repositoriesAssembly.keeperInfoRepository().getKeeperInfo().wallets.contains(where: { $0.kind == .regular })
      } catch {
        return false
      }
    }()
    if hasMnemonics && hasRegularWallet {
      openConfirmPasscode(phrase: phrase, revisions: revisions)
    } else {
      openCreatePasscode(phrase: phrase, revisions: revisions)
    }
  }

  func openCreatePasscode(phrase: [String], revisions: [WalletContractVersion]) {
    let coordinator = PasscodeCreateCoordinator(
      router: router
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      self?.removeChild(coordinator)
      self?.router.dismiss(animated: true, completion: {
        self?.didCancel?()
      })
    }
    
    coordinator.didCreatePasscode = { [weak self] passcode in
      self?.openCustomizeWallet(
        phrase: phrase,
        revisions: revisions,
        passcode: passcode,
        animated: true
      )
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openConfirmPasscode(phrase: [String], revisions: [WalletContractVersion]) {
    PasscodeInputCoordinator.present(
      parentCoordinator: self,
      parentRouter: self.router,
      mnemonicsRepository: walletsUpdateAssembly.repositoriesAssembly.mnemonicsRepository(),
      securityStore: storesAssembly.securityStore,
      onCancel: {},
      onInput: { [weak self] passcode in
        self?.openCustomizeWallet(
          phrase: phrase,
          revisions: revisions,
          passcode: passcode,
          animated: true
        )
      }
    )
  }
  
  func openCustomizeWallet(phrase: [String],
                           revisions: [WalletContractVersion],
                           passcode: String,
                           animated: Bool) {
    let module = customizeWalletModule()
    
    module.output.didCustomizeWallet = { [weak self] model in
      guard let self else { return }
      Task {
        do {
          try await self.importWallet(
            phrase: phrase,
            revisions: revisions,
            model: model,
            passcode: passcode
          )
          await MainActor.run {
            self.didImportWallets?()
          }
        } catch {
          print("Log: Wallet import failed \(error)")
        }
      }
    }
    
    module.view.setupBackButton()
    router.push(viewController: module.view, animated: animated)
  }
  
  func importWallet(phrase: [String],
                    revisions: [WalletContractVersion],
                    model: CustomizeWalletModel,
                    passcode: String) async throws {
    
    self.analyticsProvider.logEvent(eventKey: .importWallet)
    
    let addController = walletsUpdateAssembly.walletAddController()
    let metaData = WalletMetaData(
      label: model.name,
      tintColor: model.tintColor,
      icon: model.icon)
    try await addController.importWallets(
      phrase: phrase,
      revisions: revisions,
      metaData: metaData,
      passcode: passcode,
      isTestnet: isTestnet
    )
  }
}
