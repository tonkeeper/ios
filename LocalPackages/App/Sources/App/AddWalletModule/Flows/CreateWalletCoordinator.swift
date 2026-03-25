import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit
import UserNotifications

public final class CreateWalletCoordinator: RouterCoordinator<ViewControllerRouter> {
    public var didCancel: (() -> Void)?
    public var didCreateWallet: (() -> Void)?

    private let walletsUpdateAssembly: WalletsUpdateAssembly
    private let analyticsProvider: AnalyticsProvider
    private let storesAssembly: StoresAssembly
    private let customizeWalletModule: () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>

    init(
        router: ViewControllerRouter,
        analyticsProvider: AnalyticsProvider,
        walletsUpdateAssembly: WalletsUpdateAssembly,
        storesAssembly: StoresAssembly,
        customizeWalletModule: @escaping () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>
    ) {
        self.walletsUpdateAssembly = walletsUpdateAssembly
        self.analyticsProvider = analyticsProvider
        self.customizeWalletModule = customizeWalletModule
        self.storesAssembly = storesAssembly
        super.init(router: router)
    }

    override public func start() {
        let hasMnemonics = walletsUpdateAssembly.secureAssembly.mnemonicsRepository().hasMnemonics()
        let hasRegularWallet = { [walletsUpdateAssembly] in
            do {
                return try walletsUpdateAssembly.repositoriesAssembly.keeperInfoRepository().getKeeperInfo().wallets.contains(where: { $0.kind == .regular })
            } catch {
                return false
            }
        }()
        if hasMnemonics, hasRegularWallet {
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
                let phrase = TonSwift.Mnemonic.mnemonicNew()
                self?.openBackupIntro(
                    router: router,
                    animated: true,
                    passcode: passcode,
                    phrase: phrase
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
            mnemonicsRepository: walletsUpdateAssembly.secureAssembly.mnemonicsRepository(),
            securityStore: storesAssembly.securityStore,
            onCancel: { [weak self] in
                self?.didCancel?()
            },
            onInput: { [weak self] passcode in
                let navigationController = TKNavigationController()
                navigationController.configureTransparentAppearance()
                let phrase = TonSwift.Mnemonic.mnemonicNew()
                self?.openBackupIntro(
                    router: NavigationControllerRouter(rootViewController: navigationController),
                    animated: false,
                    passcode: passcode,
                    phrase: phrase
                )
                self?.router.present(navigationController, onDismiss: { [weak self] in
                    self?.didCancel?()
                })
            }
        )
    }

    func openCustomizeWallet(
        router: NavigationControllerRouter,
        animated: Bool,
        passcode: String,
        phrase: [String],
        backupDate: Date?
    ) {
        let module = customizeWalletModule()

        module.output.didCustomizeWallet = { [weak self] model in
            guard let self else { return }
            Task {
                let trace = Trace(name: "create_wallet")
                defer {
                    trace.stop()
                }

                do {
                    self.analyticsProvider.log(eventKey: .generateWallet)
                    try await self.createWallet(
                        model: model,
                        passcode: passcode,
                        phrase: phrase,
                        backupDate: backupDate
                    )
                    await MainActor.run {
                        self.didCreateWallet?()
                        router.dismiss(animated: true)
                    }
                    trace.setValue("success", forAttribute: "result")
                } catch {
                    Log.e("Wallet creation failed", extraInfo: [
                        "error": error.localizedDescription,
                    ])
                    trace.setValue("fail", forAttribute: "result")
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

    func createWallet(
        model: CustomizeWalletModel,
        passcode: String,
        phrase: [String],
        backupDate: Date?
    ) async throws {
        let addController = walletsUpdateAssembly.walletAddController()
        let metaData = WalletMetaData(
            label: model.name,
            tintColor: model.tintColor,
            icon: model.icon
        )
        try await addController.createWallet(
            metaData: metaData,
            passcode: passcode,
            mnemonicWords: phrase,
            setupSettings: WalletSetupSettings(backupDate: backupDate)
        )
    }
}

private extension CreateWalletCoordinator {
    func openBackupIntro(
        router: NavigationControllerRouter,
        animated: Bool,
        passcode: String,
        phrase: [String]
    ) {
        let model = OnboardingInfoView.Model(
            icon: .TKUIKit.Icons.Size128.textbook,
            title: TKLocales.Onboarding.BackupIntro.title,
            subtitle: TKLocales.Onboarding.BackupIntro.caption,
            buttonTitle: TKLocales.Actions.continueAction
        )
        let viewController = OnboardingInfoViewController(model: model)
        viewController.isInteractivePopDisabled = true
        viewController.didTapContinue = { [weak self] in
            self?.openRecoveryPhrase(
                router: router,
                passcode: passcode,
                phrase: phrase
            )
        }
        viewController.navigationItem.hidesBackButton = true
        viewController.navigationItem.leftBarButtonItem = nil
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            customView: makeLaterButton { [weak self] in
                self?.openCustomizeWallet(
                    router: router,
                    animated: true,
                    passcode: passcode,
                    phrase: phrase,
                    backupDate: nil
                )
            }
        )
        router.push(viewController: viewController, animated: animated)
    }

    func openRecoveryPhrase(
        router: NavigationControllerRouter,
        passcode: String,
        phrase: [String]
    ) {
        var provider = OnboardingRecoveryPhraseDataProvider(phrase: phrase)
        provider.didTapNext = { [weak self] in
            self?.openCheckRecoveryPhrase(
                router: router,
                passcode: passcode,
                phrase: phrase
            )
        }
        let module = TKRecoveryPhraseAssembly.module(provider: provider)
        module.viewController.setupBackButton()
        router.push(viewController: module.viewController)
    }

    func openCheckRecoveryPhrase(
        router: NavigationControllerRouter,
        passcode: String,
        phrase: [String]
    ) {
        let module = TKCheckRecoveryPhraseAssembly.module(
            provider: OnboardingCheckRecoveryPhraseProvider(phrase: phrase)
        )
        module.output.didCheckRecoveryPhrase = { [weak self] in
            self?.openCustomizeWallet(
                router: router,
                animated: true,
                passcode: passcode,
                phrase: phrase,
                backupDate: Date()
            )
        }
        module.viewController.setupBackButton()
        router.push(viewController: module.viewController)
    }
}

private extension CreateWalletCoordinator {
    func makeLaterButton(action: @escaping () -> Void) -> UIView {
        let button = TKUIHeaderTitleIconButton()
        button.configure(
            model: TKUIButtonTitleIconContentView.Model(
                title: TKLocales.Onboarding.BackupIntro.later
            )
        )
        button.addTapAction(action)
        button.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        return button
    }
}
