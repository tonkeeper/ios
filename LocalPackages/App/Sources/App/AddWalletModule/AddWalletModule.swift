import UIKit
import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore
import TonSwift

struct AddWalletModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createAddWalletCoordinator(options: [AddWalletOption],
                                  createPasscode: Bool = false,
                                  router: ViewControllerRouter) -> AddWalletCoordinator {
    
    var createPasscodeCoordinatorProvider: ((NavigationControllerRouter) -> CreatePasscodeCoordinator)?
    if createPasscode {
      createPasscodeCoordinatorProvider = { router in
        PasscodeModule(
          dependencies: PasscodeModule.Dependencies(
            passcodeAssembly: dependencies.passcodeAssembly
          )
        ).createCreatePasscodeCoordinator(router: router)
      }
    }
    
    let coordinator = AddWalletCoordinator(
      router: router,
      options: options,
      walletAddController: dependencies.walletsUpdateAssembly.walletAddController(),
      createWalletCoordinatorProvider:  { router in
        return createCreateWalletCoordinator(router: router)
      },
      importWalletCoordinatorProvider: { router in
        return createImportWalletCoordinator(router: router)
      },
      importWatchOnlyWalletCoordinatorProvider: { router in
        return createImportWatchOnlyWalletCoordinator(router: router)
      }, pairSignerCoordinatorProvider: { router in
        return createPairSignerCoordinator(router: router)
      }, createPasscodeCoordinatorProvider: createPasscodeCoordinatorProvider
    )
    
    return coordinator
  }
  
  func createImportWalletCoordinator(router: NavigationControllerRouter) -> ImportWalletCoordinator {
    let coordinator = ImportWalletCoordinator(
      router: router,
      walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
      customizeWalletModule: {
        self.createCustomizeWalletModule(
          name: nil,
          tintColor: nil,
          emoji: nil,
          configurator: AddWalletCustomizeWalletViewModelConfigurator()
        )
      }
    )
    
    return coordinator
  }
  
  func createCustomizeWalletModule(name: String? = nil,
                                   tintColor: WalletTintColor? = nil,
                                   emoji: String? = nil,
                                   configurator: CustomizeWalletViewModelConfigurator) -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void> {
    return CustomizeWalletAssembly.module(
      name: name,
      tintColor: tintColor,
      emoji: emoji,
      configurator: configurator
    )
  }
  
  public func createRecoveryPhraseCoordinator(router: NavigationControllerRouter) -> RecoveryPhraseCoordinator {
    let coordinator = RecoveryPhraseCoordinator(
      router: router,
      walletsUpdateAssembly: dependencies.walletsUpdateAssembly
    )
    
    return coordinator
  }
  
  public func createPairSignerImportCoordinator(publicKey: TonSwift.PublicKey, name: String, router: NavigationControllerRouter) -> PairSignerImportCoordinator {
    PairSignerImportCoordinator(
      publicKey: publicKey,
      name: name,
      router: router,
      walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
      customizeWalletModule: {
        self.createCustomizeWalletModule(
          name: name,
          tintColor: nil,
          emoji: nil,
          configurator: AddWalletCustomizeWalletViewModelConfigurator()
        )
      }
    )
  }
  
  public func createPairSignerCoordinator(router: NavigationControllerRouter) -> PairSignerCoordinator {
    PairSignerCoordinator(
      scannerAssembly: dependencies.scannerAssembly,
      walletUpdateAssembly: dependencies.walletsUpdateAssembly,
      coreAssembly: dependencies.coreAssembly,
      router: router,
      pairSignerImportCoordinatorProvider: { router, publicKey, name in
        self.createPairSignerImportCoordinator(publicKey: publicKey, name: name, router: router)
      }
    )
  }
}

private extension AddWalletModule {
  func createCreateWalletCoordinator(router: NavigationControllerRouter) -> CreateWalletCoordinator {
    let coordinator = CreateWalletCoordinator(
      router: router,
      walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
      customizeWalletModule: {
        self.createCustomizeWalletModule(
          name: nil,
          tintColor: nil,
          emoji: nil,
          configurator: AddWalletCustomizeWalletViewModelConfigurator()
        )
      }
    )
    
    return coordinator
  }
  
  func createImportWatchOnlyWalletCoordinator(router: NavigationControllerRouter) -> ImportWatchOnlyWalletCoordinator {
    let coordinator = ImportWatchOnlyWalletCoordinator(
      router: router,
      walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
      customizeWalletModule: { name in
        self.createCustomizeWalletModule(
          name: name,
          tintColor: nil,
          emoji: nil,
          configurator: AddWalletCustomizeWalletViewModelConfigurator()
        )
      }
    )
    
    return coordinator
  }
}

extension AddWalletModule {
  struct Dependencies {
    let walletsUpdateAssembly: KeeperCore.WalletsUpdateAssembly
    let coreAssembly: TKCore.CoreAssembly
    let scannerAssembly: KeeperCore.ScannerAssembly
    let passcodeAssembly: KeeperCore.PasscodeAssembly
    
    public init(walletsUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
                coreAssembly: TKCore.CoreAssembly,
                scannerAssembly: KeeperCore.ScannerAssembly,
                passcodeAssembly: KeeperCore.PasscodeAssembly) {
      self.walletsUpdateAssembly = walletsUpdateAssembly
      self.coreAssembly = coreAssembly
      self.scannerAssembly = scannerAssembly
      self.passcodeAssembly = passcodeAssembly
    }
  }
}
