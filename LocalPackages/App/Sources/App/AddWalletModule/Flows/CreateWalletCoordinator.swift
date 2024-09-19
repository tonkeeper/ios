import UIKit
import KeeperCore
import TKCore
import TKCoordinator
import TKUIKit
import TKScreenKit

public final class CreateWalletCoordinator: RouterCoordinator<ViewControllerRouter> {

  public var didCancel: (() -> Void)?
  public var didCreateWallet: (() -> Void)?
  
  private let walletsUpdateAssembly: WalletsUpdateAssembly
  private let analyticsProvider: AnalyticsProvider
  private let storesAssembly: StoresAssembly
  private let customizeWalletModule: () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>
  
  init(router: ViewControllerRouter,
       analyticsProvider: AnalyticsProvider,
       walletsUpdateAssembly: WalletsUpdateAssembly,
       storesAssembly: StoresAssembly,
       customizeWalletModule: @escaping () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>) {
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.analyticsProvider = analyticsProvider
    self.customizeWalletModule = customizeWalletModule
    self.storesAssembly = storesAssembly
    super.init(router: router)
  }

  public override func start() {
    let hasMnemonics = walletsUpdateAssembly.repositoriesAssembly.mnemonicsRepository().hasMnemonics()
    let hasRegularWallet = { [walletsUpdateAssembly] in
      do {
        return try walletsUpdateAssembly.repositoriesAssembly.keeperInfoRepository().getKeeperInfo().wallets.contains(where: { $0.kind == .regular })
      } catch {
        return false
      }
    }()
    if hasMnemonics && hasRegularWallet {
      openConfirmPasscode()
    } else {
      openCreatePasscode()
    }
  }
}

private extension CreateWalletCoordinator {
  func openCreatePasscode() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    let router = NavigationControllerRouter(rootViewController: navigationController)
    
    PasscodeCreateCoordinator.present(
      parentCoordinator: self,
      parentRouter: router,
      repositoriesAssembly: walletsUpdateAssembly.repositoriesAssembly,
      onCancel: { [weak self] in
        self?.router.dismiss(animated: true, completion: {
          self?.didCancel?()
        })
      },
      onCreate: { [weak self] passcode in
        self?.openCustomizeWallet(
          router: router,
          animated: true,
          passcode: passcode
        )
      }
    )

    self.router.present(navigationController, onDismiss: { [weak self] in
      self?.didCancel?()
    })
  }
  
  func openConfirmPasscode() {
    PasscodeInputCoordinator.present(
      parentCoordinator: self,
      parentRouter: self.router,
      mnemonicsRepository: walletsUpdateAssembly.repositoriesAssembly.mnemonicsRepository(),
      securityStore: storesAssembly.securityStore,
      onCancel: { [weak self] in
        self?.didCancel?()
      },
      onInput: { [weak self] passcode in
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()
        self?.openCustomizeWallet(
          router: NavigationControllerRouter(rootViewController: navigationController), 
          animated: false,
          passcode: passcode
        )
        self?.router.present(navigationController, onDismiss: { [weak self] in
          self?.didCancel?()
        })
      }
    )
  }
  
  func openCustomizeWallet(router: NavigationControllerRouter,
                           animated: Bool,
                           passcode: String) {
    let module = customizeWalletModule()
    
    module.output.didCustomizeWallet = { [weak self] model in
      guard let self else { return }
      Task {
        do {
          self.analyticsProvider.logEvent(eventKey: .generateWallet)
          try await self.createWallet(model: model, passcode: passcode)
          await MainActor.run {
            self.didCreateWallet?()
            router.dismiss(animated: true)
          }
        } catch {
          print("Log: Wallet creation failed \(error)")
        }
      }
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      module.view.setupLeftCloseButton { [weak self] in
        router.dismiss(animated: true) {
          self?.didCancel?()
        }
      }
    } else {
      module.view.setupBackButton()
    }
    
    router.push(viewController: module.view, animated: animated)
  }
  
  func createWallet(model: CustomizeWalletModel, passcode: String) async throws {
    let addController = walletsUpdateAssembly.walletAddController()
    let metaData = WalletMetaData(
      label: model.name,
      tintColor: model.tintColor,
      icon: model.icon)
    try await addController.createWallet(metaData: metaData, passcode: passcode)
  }
}
