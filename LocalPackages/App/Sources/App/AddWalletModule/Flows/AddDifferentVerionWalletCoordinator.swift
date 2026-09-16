import KeeperCore
import TKCoordinator
import TKCore
import TKScreenKit
import TKUIKit
import UIKit

final class AddDifferentVersionWalletCoordinator: RouterCoordinator<ViewControllerRouter> {
    var didCancel: (() -> Void)?
    var didAddedWallet: (() -> Void)?

    private let revisionToAdd: WalletContractVersion
    private let wallet: Wallet
    private let securityStore: SecurityStore
    private let mnemonicAccess: MnemonicAccess
    private let addController: WalletAddController
    private let analyticsProvider: AnalyticsProvider

    init(
        router: ViewControllerRouter,
        revisionToAdd: WalletContractVersion,
        wallet: Wallet,
        securityStore: SecurityStore,
        mnemonicAccess: MnemonicAccess,
        addController: WalletAddController,
        analyticsProvider: AnalyticsProvider
    ) {
        self.revisionToAdd = revisionToAdd
        self.wallet = wallet
        self.securityStore = securityStore
        self.mnemonicAccess = mnemonicAccess
        self.addController = addController
        self.analyticsProvider = analyticsProvider
        super.init(router: router)
    }

    override func start() {
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
            mnemonicAccess: mnemonicAccess,
            securityStore: securityStore,
            analyticsProvider: analyticsProvider,
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
    }
}
