import AppUI
import CryptoKit
import KeeperCore
import Security
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit

final class CreateWalletCoordinator: RouterCoordinator<ViewControllerRouter> {
    enum Mode {
        case regular
        case multichain

        var requiresBackup: Bool {
            switch self {
            case .regular:
                true
            case .multichain:
                true
            }
        }

        var walletMode: WalletMode {
            switch self {
            case .regular:
                .single
            case .multichain:
                .multi
            }
        }
    }

    var didCancel: (() -> Void)?
    var didCreateWallet: (() -> Void)?
    var didRequestBack: (() -> Void)?

    private let walletsUpdateAssembly: WalletsUpdateAssembly
    private let analyticsProvider: AnalyticsProvider
    private let storesAssembly: StoresAssembly
    private let hasPasscodeChecker: HasPasscodeChecker
    private let multichainAssembly: MultichainAssembly
    private let configurationAssembly: ConfigurationAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let customizeWalletModule: () -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void>
    private let mode: Mode
    private let analyticsContext: WalletFlowAnalyticsContext
    private var migrationCoordinator: WalletMigrationCoordinator?

    init(
        router: ViewControllerRouter,
        analyticsProvider: AnalyticsProvider,
        walletsUpdateAssembly: WalletsUpdateAssembly,
        multichainAssembly: MultichainAssembly,
        hasPasscodeChecker: HasPasscodeChecker,
        storesAssembly: StoresAssembly,
        configurationAssembly: ConfigurationAssembly,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        mode: Mode = .regular,
        analyticsContext: WalletFlowAnalyticsContext,
        customizeWalletModule: @escaping () -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void>
    ) {
        self.walletsUpdateAssembly = walletsUpdateAssembly
        self.analyticsProvider = analyticsProvider
        self.customizeWalletModule = customizeWalletModule
        self.hasPasscodeChecker = hasPasscodeChecker
        self.multichainAssembly = multichainAssembly
        self.storesAssembly = storesAssembly
        self.configurationAssembly = configurationAssembly
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.mode = mode
        self.analyticsContext = analyticsContext
        super.init(router: router)
    }

    override func start() {
        analyticsProvider.log(WalletCreateStarted(walletMode: mode.walletMode, from: analyticsContext.from))

        if hasPasscodeChecker.hasPasscode {
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
            biometryEnabler: makePasscodeBiometryEnabler(),
            onCancel: { [weak self] in
                self?.router.dismiss(animated: true, completion: {
                    self?.didCancel?()
                })
            },
            onMismatch: { [weak self] in
                guard let self else { return }
                analyticsContext.logOnboarding(OnboardingPasscodeMismatch(), using: analyticsProvider)
            },
            onCreate: { [weak self] passcode in
                guard let self else { return }
                analyticsContext.logOnboarding(OnboardingPasscodeCreated(), using: analyticsProvider)
                guard let phrase = makeMnemonic() else {
                    return ToastPresenter.showToast(
                        configuration: .defaultConfiguration(text: TKLocales.Errors.unknown)
                    )
                }
                self.openPostPasscodeFlow(
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
            mnemonicAccess: walletsUpdateAssembly.secureAssembly.mnemonicAccess,
            securityStore: storesAssembly.securityStore,
            analyticsProvider: analyticsProvider,
            onCancel: { [weak self] in
                self?.didCancel?()
            },
            onInput: { [weak self] passcode in
                guard let self else { return }
                guard let phrase = makeMnemonic() else {
                    return ToastPresenter.showToast(
                        configuration: .defaultConfiguration(text: TKLocales.Errors.unknown)
                    )
                }
                let navigationController = TKNavigationController()
                navigationController.configureTransparentAppearance()
                self.openPostPasscodeFlow(
                    router: NavigationControllerRouter(rootViewController: navigationController),
                    animated: false,
                    passcode: passcode,
                    phrase: phrase
                )
                self.router.present(navigationController, onDismiss: { [weak self] in
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

        analyticsContext.logOnboarding(OnboardingViewCustomize(), using: analyticsProvider)

        module.output.didCustomizeWallet = { [weak self] model in
            guard let self else { return }
            Task {
                let trace = Trace(name: "create_wallet")
                defer {
                    trace.stop()
                }

                do {
                    self.analyticsContext.logOnboarding(OnboardingClickCustomizeContinue(), using: self.analyticsProvider)
                    try await self.createWallet(
                        model: model,
                        passcode: passcode,
                        phrase: phrase,
                        backupDate: backupDate
                    )
                    self.analyticsProvider.log(WalletCreateSuccess(
                        walletMode: self.mode.walletMode,
                        backedUp: backupDate != nil,
                        from: self.analyticsContext.from
                    ))
                    let shouldOfferMigration = await self.shouldOfferOnboardingMigration()
                    await MainActor.run {
                        if shouldOfferMigration,
                           let wallet = try? self.storesAssembly.walletsStore.activeWallet
                        {
                            self.openOnboardingMigration(
                                router: router,
                                wallet: wallet
                            )
                        } else {
                            self.finishWalletCreation(router: router)
                        }
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
            module.view.setupHeaderLeftCloseButton { [weak self] in
                router.dismiss(animated: true) {
                    self?.didCancel?()
                }
            }
        } else {
            module.view.setupHeaderBackButton()
        }

        router.push(viewController: module.view, animated: animated)
    }

    func createWallet(
        model: CustomizeWalletModel,
        passcode: String,
        phrase: [String],
        backupDate: Date?
    ) async throws {
        let addController = walletsUpdateAssembly.walletAddController(
            multichainAssembly: multichainAssembly
        )
        let metaData = WalletMetaData(
            label: model.name,
            tintColor: model.tintColor,
            icon: model.icon
        )
        try await addController.createWallet(
            metaData: metaData,
            passcode: passcode,
            mnemonicWords: phrase,
            setupSettings: WalletSetupSettings(backupDate: backupDate),
            derivationType: mode == .multichain ? .bip39 : nil
        )
    }

    func shouldOfferOnboardingMigration() async -> Bool {
        guard mode == .multichain else {
            return false
        }

        return await WalletMigrationVisibility.hasMigratableLegacyWallets(
            wallets: storesAssembly.walletsStore.wallets,
            walletMigrationService: keeperCoreMainAssembly.servicesAssembly.walletMigrationService(),
            currency: storesAssembly.currencyStore.state
        )
    }

    func openOnboardingMigration(
        router: NavigationControllerRouter,
        wallet: Wallet
    ) {
        let coordinator = WalletMigrationCoordinator(
            wallet: wallet,
            source: .onboarding,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: router,
            depositPendingTracker: DepositPendingTracker(),
            presentation: .embedded
        )
        coordinator.didFinish = { [weak self, weak coordinator] _ in
            guard let self else { return }
            self.migrationCoordinator = nil
            if let coordinator {
                self.removeChild(coordinator)
            }
            self.finishWalletCreation(router: router)
        }
        migrationCoordinator = coordinator
        addChild(coordinator)
        coordinator.start()
    }

    func finishWalletCreation(router: NavigationControllerRouter) {
        didCreateWallet?()
        router.dismiss(animated: true)
    }
}

private extension CreateWalletCoordinator {
    func makeMnemonic() -> [String]? {
        switch mode {
        case .regular:
            return TonSwift.Mnemonic.mnemonicNew()
        case .multichain:
            do {
                return try multichainAssembly.chainKitService.makeMnemonic()
            } catch {
                switch error {
                case let .unknown(message):
                    Log.e("failed to create multichain mnemonic words due to error: \(message)")
                }
                return nil
            }
        }
    }
}

private extension CreateWalletCoordinator {
    func openPostPasscodeFlow(
        router: NavigationControllerRouter,
        animated: Bool,
        passcode: String,
        phrase: [String]
    ) {
        guard !phrase.isEmpty else {
            Log.e("Wallet mnemonic generation failed")
            return
        }

        if mode.requiresBackup {
            openBackupIntro(
                router: router,
                animated: animated,
                passcode: passcode,
                phrase: phrase
            )
        } else {
            openNotifications(
                router: router,
                animated: animated,
                passcode: passcode,
                phrase: phrase,
                backupDate: nil
            )
        }
    }

    func openBackupIntro(
        router: NavigationControllerRouter,
        animated: Bool,
        passcode: String,
        phrase: [String]
    ) {
        let state = OnboardingInfoScreenState(
            icon: .TKUIKit.Icons.Size128.textbook,
            iconTintColor: .accentBlue,
            title: TKLocales.Onboarding.BackupIntro.title,
            subtitle: TKLocales.Onboarding.BackupIntro.caption,
            buttonTitle: TKLocales.Actions.continueAction
        )
        let viewController = OnboardingInfoViewController(state: state)
        analyticsProvider.log(WalletBackupStarted(walletMode: mode.walletMode, source: .onboarding))
        viewController.didTapContinue = { [weak self] in
            self?.openRecoveryPhrase(
                router: router,
                passcode: passcode,
                phrase: phrase
            )
        }
        if router.rootViewController.viewControllers.isEmpty {
            viewController.isInteractivePopDisabled = true
            viewController.setupHeaderBackButton { [weak self] in
                self?.didRequestBack?()
            }
        } else {
            viewController.setupHeaderBackButton()
        }
        viewController.setupHeaderSkipButton(title: TKLocales.Onboarding.BackupIntro.later) { [weak self] in
            guard let self else { return }
            analyticsProvider.log(WalletBackupSkip(walletMode: mode.walletMode, source: .onboarding))
            openNotifications(
                router: router,
                animated: true,
                passcode: passcode,
                phrase: phrase,
                backupDate: nil
            )
        }
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
        module.viewController.setupHeaderBackButton()
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
            guard let self else { return }
            analyticsProvider.log(WalletBackupSuccess(walletMode: mode.walletMode, source: .onboarding))
            openNotifications(
                router: router,
                animated: true,
                passcode: passcode,
                phrase: phrase,
                backupDate: Date()
            )
        }
        module.output.didFailCheckRecoveryPhrase = { [weak self] in
            guard let self else { return }
            analyticsProvider.logWalletBackupMismatch(walletMode: mode.walletMode, source: .onboarding)
        }
        module.viewController.setupHeaderBackButton()
        router.push(viewController: module.viewController)
    }

    func openNotifications(
        router: NavigationControllerRouter,
        animated: Bool,
        passcode: String,
        phrase: [String],
        backupDate: Date?
    ) {
        OnboardingNotificationsStep.push(
            router: router,
            animated: animated
        ) { [weak self] in
            self?.openCustomizeWallet(
                router: router,
                animated: true,
                passcode: passcode,
                phrase: phrase,
                backupDate: backupDate
            )
        }
    }
}

private extension CreateWalletCoordinator {
    func makePasscodeBiometryEnabler() -> PasscodeBiometryEnabler? {
        guard analyticsContext.from == .onboarding else { return nil }
        return PasscodeBiometryEnabler(
            mnemonicAccess: walletsUpdateAssembly.secureAssembly.mnemonicAccess,
            securityStore: storesAssembly.securityStore
        )
    }
}
