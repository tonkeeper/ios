import UIKit
import KeeperCore
import TKCore
import TKCoordinator
import TKUIKit
import TKScreenKit

public final class AddDifferentVersionWalletCoordinator: RouterCoordinator<ViewControllerRouter> {

  public var didCancel: (() -> Void)?
  public var didAddedWallet: (() -> Void)?
  
  private let revisionToAdd: WalletContractVersion
  private let wallet: Wallet
  private let securityStore: SecurityStore
  private let mnemonicsRepository: MnemonicsRepository
  private let addController: WalletAddController
  private let analyticsProvider: AnalyticsProvider
  
  init(router: ViewControllerRouter,
       revisionToAdd: WalletContractVersion,
       wallet: Wallet,
       securityStore: SecurityStore,
       mnemonicsRepository: MnemonicsRepository,
       addController: WalletAddController,
       analyticsProvider: AnalyticsProvider) {
    self.revisionToAdd = revisionToAdd
    self.wallet = wallet
    self.securityStore = securityStore
    self.mnemonicsRepository = mnemonicsRepository
    self.addController = addController
    self.analyticsProvider = analyticsProvider
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
    
    PasscodeInputCoordinator.present(
      parentCoordinator: self,
      parentRouter: self.router,
      mnemonicsRepository: mnemonicsRepository,
      securityStore: securityStore,
      onCancel: { [weak self] in
        self?.didCancel?()
      },
      onInput: { [weak self] passcode in
        guard let self else { return }
        Task {
          do {
            try await self.importWallet(passcode: passcode)
            await MainActor.run {
              self.didAddedWallet?()
            }
          } catch {
            await MainActor.run {
              self.didCancel?()
            }
          }
        }
      }
    )
    
    self.router.present(navigationController, onDismiss: { [weak self] in
      self?.didCancel?()
    })
  }
  
  func importWallet(passcode: String) async throws {
    try await addController.addWalletRevision(wallet: wallet, revision: revisionToAdd, passcode: passcode)
    self.analyticsProvider.logEvent(eventKey: .importWallet)
  }
}
