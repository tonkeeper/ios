import UIKit
import KeeperCore
import TKCore
import TKCoordinator
import TKUIKit
import TKScreenKit

public final class AddDifferentVersionWalletCoordinator: RouterCoordinator<ViewControllerRouter> {

  public var didCancel: (() -> Void)?
  public var didAddedWallet: (() -> Void)?
  
  private let walletsUpdateAssembly: WalletsUpdateAssembly
  private let analyticsProvider: AnalyticsProvider
  private let storesAssembly: StoresAssembly
  private let wallet: Wallet
  private let revisionToAdd: WalletContractVersion
  
  init(router: ViewControllerRouter,
       analyticsProvider: AnalyticsProvider,
       walletsUpdateAssembly: WalletsUpdateAssembly,
       wallet: Wallet,
       revisionToAdd: WalletContractVersion,
       storesAssembly: StoresAssembly
  ) {
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.analyticsProvider = analyticsProvider
    self.storesAssembly = storesAssembly
    self.revisionToAdd = revisionToAdd
    self.wallet = wallet
    super.init(router: router)
  }

  public override func start() {
    openConfirmPasscode()
  }
}

private extension AddDifferentVersionWalletCoordinator {
  func openConfirmPasscode() {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    let router = NavigationControllerRouter(rootViewController: navigationController)
    
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
        
        guard let self else { return }
        Task {
          do {
            try await self.openWalletsList(
              router: NavigationControllerRouter(rootViewController: navigationController),
              animated: false,
              passcode: passcode
            )
          } catch {
            print("openWalletsList error:", error)
          }
        }
      }
    )
    
    self.router.present(navigationController, onDismiss: { [weak self] in
      self?.didCancel?()
    })
  }

  
  func openWalletsList(router: NavigationControllerRouter,
                       animated: Bool,
                       passcode: String) async throws {
    let mnemonic = try await walletsUpdateAssembly.repositoriesAssembly.mnemonicsRepository().getMnemonic(
      wallet: wallet,
      password: passcode
    )
    try await importWallet(phrase: mnemonic.mnemonicWords, passcode: passcode)
  }
  
  func importWallet(phrase: [String],
                    passcode: String) async throws {
    
    self.analyticsProvider.logEvent(eventKey: .importWallet)
    
    let addController = walletsUpdateAssembly.walletAddController()
    let metaData = self.wallet.metaData
    try await addController.importWallets(
      phrase: phrase,
      revisions: [self.revisionToAdd],
      metaData: metaData,
      passcode: passcode,
      isTestnet: self.wallet.isTestnet
    )
  }
}
