import AppUI
import KeeperCore
import TKCoordinator
import TKCore
import TKLogging
import TKScreenKit
import TKUIKit
import UIKit

final class SettingsRecoveryPhraseCoordinator: RouterCoordinator<NavigationControllerRouter> {
    private let wallet: Wallet
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly

    init(
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter
    ) {
        self.wallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        super.init(router: router)
    }

    override func start() {
        openSafetyCheck()
    }

    func openSafetyCheck() {
        let bottomSheetViewController = PopupContentPresenter.present(
            from: router.rootViewController
        ) { dismisser in
            BackupSafetyCheckView(
                onContinue: { [weak self] in
                    dismisser.dismiss {
                        self?.openPasscodeInput()
                    }
                }
            )
        }

        bottomSheetViewController.didClose = { [weak self] _ in
            self?.didFinish?(self)
        }
    }

    func openPasscodeInput() {
        PasscodeInputCoordinator.present(
            parentCoordinator: self,
            parentRouter: router,
            mnemonicAccess: keeperCoreMainAssembly.mnemonicAccess,
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
            analyticsProvider: coreAssembly.analyticsProvider,
            onCancel: { [weak self] in
                self?.didFinish?(self)
            },
            onInput: { [weak self, wallet, keeperCoreMainAssembly] passcode in
                guard let self else { return }
                Task {
                    do {
                        let mnemonic = try await keeperCoreMainAssembly.mnemonicAccess.getMnemonic(
                            wallet: wallet,
                            passcode: passcode
                        )
                        await MainActor.run {
                            self.openRecoveryPhrase(mnemonic.mnemonicWords)
                        }
                    } catch {
                        await MainActor.run {
                            ToastPresenter.showToast(configuration: .failed)
                        }
                    }
                }
            }
        )
    }

    func openRecoveryPhrase(_ phrase: [String]) {
        let balanceStore = keeperCoreMainAssembly.storesAssembly.balanceStore
        let tronBalanceIsZero = balanceStore.getState()[wallet]?.walletBalance.tronBalance?.amount.isZero ?? true

        let configuration = keeperCoreMainAssembly.configurationAssembly.configuration
        let tronDisabled = configuration.flag(\.tronDisabled, network: wallet.network) && tronBalanceIsZero

        let provider = SettingsRecoveryPhraseProvider(
            wallet: wallet,
            phrase: phrase,
            shouldShowTron: !tronDisabled
        )

        let module = TKRecoveryPhraseAssembly.module(
            provider: provider
        )

        let navigationController = TKNavigationController(rootViewController: module.viewController)
        navigationController.configureTransparentAppearance()

        provider.didTapTRC20Button = { [weak self, weak navigationController] in
            guard let navigationController else { return }
            self?.openTRC20RecoveryPhrase(tonPhrase: phrase, navigationController: navigationController)
        }

        module.viewController.setupHeaderCloseButton { [weak self, weak navigationController] in
            navigationController?.dismiss(animated: true, completion: {
                self?.didFinish?(self)
            })
        }

        router.present(navigationController)
    }

    func openTRC20RecoveryPhrase(tonPhrase: [String], navigationController: UINavigationController) {
        let provider = SettingsTRC20RecoveryPhraseProvider(
            wallet: wallet,
            tonMnemonic: tonPhrase
        )

        let module = TKRecoveryPhraseAssembly.module(
            provider: provider
        )

        module.viewController.setupHeaderBackButton()

        navigationController.pushViewController(module.viewController, animated: true)
    }
}
