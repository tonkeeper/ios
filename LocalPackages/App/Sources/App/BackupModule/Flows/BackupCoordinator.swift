import AppUI
import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKScreenKit
import TKUIKit
import UIKit

final class BackupCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didCompleteBackup: (() -> Void)?

    private let wallet: Wallet
    private let source: BackupSource
    private let startsWithIntro: Bool
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly

    init(
        wallet: Wallet,
        source: BackupSource,
        startsWithIntro: Bool = false,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter
    ) {
        self.wallet = wallet
        self.source = source
        self.startsWithIntro = startsWithIntro
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        super.init(router: router)
    }

    override func start() {
        coreAssembly.analyticsProvider.log(
            WalletBackupStarted(walletMode: WalletMode(wallet: wallet), source: source)
        )
        if startsWithIntro {
            openIntro()
        } else {
            openSafetyCheck()
        }
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

    func openIntro() {
        let viewController = OnboardingInfoViewController(
            state: OnboardingInfoScreenState(
                icon: .TKUIKit.Icons.Size128.textbook,
                iconTintColor: .accentBlue,
                title: TKLocales.Onboarding.BackupIntro.title,
                subtitle: TKLocales.Onboarding.BackupIntro.caption,
                buttonTitle: TKLocales.Actions.continueAction
            )
        )

        viewController.didTapContinue = { [weak self] in
            self?.openPasscodeInput()
        }

        viewController.setupHeaderBackButton()

        router.push(viewController: viewController)
    }

    func openPasscodeInput() {
        let onCancel: () -> Void = startsWithIntro ? {} : { [weak self] in self?.didFinish?(self) }

        PasscodeInputCoordinator.present(
            parentCoordinator: self,
            parentRouter: router,
            mnemonicAccess: keeperCoreMainAssembly.mnemonicAccess,
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
            analyticsProvider: coreAssembly.analyticsProvider,
            onCancel: onCancel,
            onInput: { [weak self, wallet, keeperCoreMainAssembly] passcode in
                guard let self else { return }
                Task {
                    do {
                        let mnemonic = try await keeperCoreMainAssembly.mnemonicAccess.getMnemonic(
                            wallet: wallet,
                            passcode: passcode
                        )
                        await MainActor.run {
                            self.openCheck(phrase: mnemonic.mnemonicWords)
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

    func openCheck(phrase: [String]) {
        if startsWithIntro {
            openCheckInline(phrase: phrase)
        } else {
            openCheckModal(phrase: phrase)
        }
    }

    func openCheckModal(phrase: [String]) {
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()

        let checkCoordinator = BackupCheckCoordinator(
            wallet: wallet,
            phrase: phrase,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            source: source,
            router: NavigationControllerRouter(rootViewController: navigationController)
        )

        checkCoordinator.didFinish = { [weak self] coordinator in
            coordinator?.router.rootViewController.dismiss(animated: true, completion: { [weak self, weak coordinator] in
                guard let self else { return }

                let hasBackup = keeperCoreMainAssembly.storesAssembly.walletsStore
                    .getWallet(id: wallet.id)?
                    .hasBackup == true
                if hasBackup {
                    didCompleteBackup?()
                }

                didFinish?(self)
                if let coordinator {
                    removeChild(coordinator)
                }
            })
        }

        addChild(checkCoordinator)
        checkCoordinator.start()

        router.present(
            checkCoordinator.router.rootViewController,
            onDismiss: { [weak self, weak checkCoordinator] in
                checkCoordinator?.router.rootViewController.dismiss(animated: true, completion: {
                    self?.didFinish?(self)
                    guard let checkCoordinator else { return }
                    self?.removeChild(checkCoordinator)
                })
            }
        )
    }

    func openCheckInline(phrase: [String]) {
        let checkCoordinator = BackupCheckCoordinator(
            wallet: wallet,
            phrase: phrase,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            source: source,
            router: router
        )
        checkCoordinator.didFinish = { [weak self] _ in
            guard let self else { return }
            removeChild(checkCoordinator)

            let hasBackup = keeperCoreMainAssembly.storesAssembly.walletsStore
                .getWallet(id: wallet.id)?
                .hasBackup == true
            guard hasBackup else { return }

            router.popToRoot { [weak self] in
                self?.didCompleteBackup?()
            }
        }

        addChild(checkCoordinator)
        checkCoordinator.start()
    }
}
