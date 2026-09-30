import KeeperCore
import KeeperCoreSensitive
import TKCoordinator
import TKCore
import TKLogging
import TKStories
import TKUIKit
import TonSwift
import UIKit

final class RootCoordinator: RouterCoordinator<ViewControllerRouter> {
    struct Dependencies {
        let coreAssembly: TKCore.CoreAssembly
        let keeperCoreRootAssembly: KeeperCore.RootAssembly
    }

    private weak var onboardingCoordinator: OnboardingCoordinator?
    private weak var mainCoordinator: MainCoordinator?

    private var activeViewController: UIViewController?

    private let dependencies: Dependencies
    private let rootController: RootController

    private let stateManager: RootCoordinatorStateManager
    private let multichainStartupController: MultichainStartupController
    private let pushNotificationsManager: PushNotificationManager
    private let argon2DeriveTimeMeasurementController: Argon2DeriveTimeMeasurementController
    private let batteryChargedAnalyticsObserver: BatteryChargedAnalyticsObserver
    private let depositCompletedAnalyticsObserver: DepositCompletedAnalyticsObserver
    private let depositPendingTracker: DepositPendingTracker
    private var foregroundObserver: NSObjectProtocol?

    deinit {
        foregroundObserver.map(NotificationCenter.default.removeObserver)
    }

    init(
        router: ViewControllerRouter,
        dependencies: Dependencies
    ) {
        self.dependencies = dependencies
        self.rootController = dependencies.keeperCoreRootAssembly.rootController()
        self.stateManager = RootCoordinatorStateManager(
            walletsStore: dependencies.keeperCoreRootAssembly.storesAssembly.walletsStore
        )
        let multichainAssembly = dependencies.keeperCoreRootAssembly.mainAssembly().multichainAssembly
        self.multichainStartupController = MultichainStartupController(
            authService: multichainAssembly.multichainAuthService,
            walletSyncController: multichainAssembly.walletSyncController
        )
        self.pushNotificationsManager = PushNotificationManager(
            appSettings: dependencies.coreAssembly.appSettings,
            uniqueIdProvider: dependencies.coreAssembly.uniqueIdProvider,
            pushNotificationTokenProvider: dependencies.coreAssembly.pushNotificationTokenProvider,
            pushNotificationAPI: dependencies.keeperCoreRootAssembly.mainAssembly().apiAssembly.pushNotificationsAPI,
            walletNotificationsStore: dependencies.keeperCoreRootAssembly.storesAssembly.walletNotificationStore,
            walletsStore: dependencies.keeperCoreRootAssembly.storesAssembly.walletsStore,
            tonConnectAppsStore: dependencies.keeperCoreRootAssembly.mainAssembly().tonConnectAssembly.tonConnectAppsStore,
            tonProofTokenService: dependencies.keeperCoreRootAssembly.servicesAssembly.tonProofTokenService(),
            multichainAuthService: multichainAssembly.multichainAuthService
        )
        self.argon2DeriveTimeMeasurementController = Argon2DeriveTimeMeasurementController(
            analyticsProvider: dependencies.coreAssembly.analyticsProvider,
            appInfoProvider: dependencies.coreAssembly.appInfoProvider
        )
        self.batteryChargedAnalyticsObserver = BatteryChargedAnalyticsObserver(
            totalBalanceStore: dependencies.keeperCoreRootAssembly.storesAssembly.totalBalanceStore,
            analyticsProvider: dependencies.coreAssembly.analyticsProvider
        )
        let depositPendingTracker = DepositPendingTracker()
        self.depositPendingTracker = depositPendingTracker
        self.depositCompletedAnalyticsObserver = DepositCompletedAnalyticsObserver(
            totalBalanceStore: dependencies.keeperCoreRootAssembly.storesAssembly.totalBalanceStore,
            depositPendingTracker: depositPendingTracker,
            analyticsProvider: dependencies.coreAssembly.analyticsProvider
        )
        super.init(router: router)
    }

    override func start(deeplink: CoordinatorDeeplink? = nil) {
        // Push setup kicks off an async registration that can reach the device session, so the
        // device-change handler has to be wired first.
        setupMultichainDeviceChangeHandling()
        setupMultichainForegroundReconcile()
        pushNotificationsManager.setup()
        rootController.loadConfigurations()
        Task {
            await multichainStartupController.startPendingUnregisterFlush()
        }

        stateManager.didUpdateState = { [weak self] state in
            self?.handleStateUpdate(state: state, deeplink: deeplink)
        }

        let state = stateManager.state
        switch state {
        case .onboarding:
            migrateRNIfNeed(deeplink: deeplink) { [weak self] isSuccess, passcode in
                if isSuccess {
                    self?.completeRNMigration(passcode: passcode)
                } else {
                    self?.openOnboarding(deeplink: deeplink)
                }
            }
        case .main:
            resolveRaffleUserIfNeeded()
            migrateBiometryIfNeed { [weak self] in
                self?.migrateNativeIfNeed { [weak self] didNeedToMigrate, isSuccess, passcode in
                    if !isSuccess {
                        self?.openOnboarding(deeplink: deeplink)
                        return
                    }
                    if didNeedToMigrate {
                        if let passcode {
                            Task {
                                await self?.performStartupEnrichment(passcode: passcode)
                                await MainActor.run {
                                    self?.openMain(deeplink: deeplink)
                                }
                                await self?.multichainStartupController.startBindingsReconcile()
                            }
                        } else {
                            // Migration can succeed without a passcode prompt; still run
                            // startup enrichment when wallets need tron/multichain backfill.
                            self?.handlePasscodeFlowIfNeeded {
                                self?.openMain(deeplink: deeplink)
                            }
                        }
                    } else {
                        self?.handlePasscodeFlowIfNeeded {
                            self?.openMain(deeplink: deeplink)
                        }
                    }
                }
            }
        }
        sendFirstLaunchAnalyticsEvent()
    }

    private func completeRNMigration(passcode: String?) {
        stateManager.reloadWalletsAfterRNMigration { [weak self] in
            guard let self else { return }
            resolveRaffleUserIfNeeded()
            if let passcode {
                Task {
                    await self.performStartupEnrichment(passcode: passcode)
                    await MainActor.run {
                        self.stateManager.didPerformRNMigration()
                    }
                    await self.multichainStartupController.startBindingsReconcile()
                }
            } else {
                handlePasscodeFlowIfNeeded { [weak self] in
                    self?.stateManager.didPerformRNMigration()
                }
            }
        }
    }

    override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
        guard let string = deeplink as? String else { return false }
        do {
            let coreDeeplink = try rootController.parseDeeplink(string: string)
            if let onboardingCoordinator {
                return onboardingCoordinator.handleDeeplink(deeplink: coreDeeplink)
            } else if let mainCoordinator {
                return mainCoordinator.handleDeeplink(
                    deeplink: coreDeeplink,
                    fromStories: false,
                    utm: UtmParameters(link: string)
                )
            } else {
                return false
            }
        } catch let error as DeeplinkParserError where error.isSilent {
            return true
        } catch {
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: error.localizedDescription))
            return false
        }
    }

    /// Has to be wired before anything can touch the device session, so a rotation during startup
    /// is never silently dropped.
    private func setupMultichainDeviceChangeHandling() {
        let multichainAssembly = dependencies.keeperCoreRootAssembly.mainAssembly().multichainAssembly
        multichainAssembly.didChangeDevice = { [weak self] in
            // Bindings are rebuilt inside KeeperCore; the push subscription is ours.
            self?.pushNotificationsManager.refreshSubscriptions()
        }
    }

    /// The startup reconcile is the only unattended one, so a launch that happened offline would
    /// otherwise leave the device without bindings until the next cold start.
    private func setupMultichainForegroundReconcile() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.multichainStartupController.startBindingsReconcile()
            }
        }
    }

    private func handlePasscodeFlowIfNeeded(completion: @escaping (() -> Void)) {
        let isLockScreen = dependencies.keeperCoreRootAssembly.storesAssembly.securityStore.getState().isLockScreen
        let tonProofTokenService = dependencies.keeperCoreRootAssembly.mainAssembly().servicesAssembly.tonProofTokenService()
        let mnemonicAccess = dependencies.keeperCoreRootAssembly.secureAssembly.mnemonicAccess
        let missedTonProofWallets = tonProofTokenService.getWalletsWithMissedToken()
        let multichainAssembly = dependencies.keeperCoreRootAssembly.mainAssembly().multichainAssembly
        let shouldEnrichStartupMultichainWallets = multichainAssembly.walletAddressesEnricher.needsStartupEnrichment
        let shouldSyncStartupMultichainWallets = multichainAssembly.walletSyncController.needsStartupSync
        let shouldMigrateLegacyTronWallets = dependencies.keeperCoreRootAssembly.mainAssembly()
            .tronUSDTAssembly
            .walletMigration()
            .needsMigration

        Task { [weak self] in
            guard let self else { return }
            let shouldWarmStartupAppKeys = await multichainAssembly.walletSyncController.needsStartupAppKeyWarm()
            await MainActor.run {
                guard isLockScreen
                    || !missedTonProofWallets.isEmpty
                    || shouldEnrichStartupMultichainWallets
                    || shouldSyncStartupMultichainWallets
                    || shouldWarmStartupAppKeys
                    || shouldMigrateLegacyTronWallets
                else {
                    completion()
                    Task {
                        await self.multichainStartupController.startBindingsReconcile()
                    }
                    return
                }

                self.showPasscode(validator: PasscodeConfirmationValidator(mnemonicAccess: mnemonicAccess)) { [weak self] passcode in
                    Task {
                        await self?.performStartupEnrichment(passcode: passcode)
                        await MainActor.run {
                            completion()
                        }
                        await self?.multichainStartupController.startBindingsReconcile()
                    }
                }
            }
        }
    }

    private func performStartupEnrichment(passcode: String) async {
        let tonProofTokenService = dependencies.keeperCoreRootAssembly.mainAssembly().servicesAssembly.tonProofTokenService()
        let mnemonicAccess = dependencies.keeperCoreRootAssembly.secureAssembly.mnemonicAccess
        let missedTonProofWallets = tonProofTokenService.getWalletsWithMissedToken()
        let multichainAssembly = dependencies.keeperCoreRootAssembly.mainAssembly().multichainAssembly
        let multichainWalletEnricher = multichainAssembly.walletAddressesEnricher
        let multichainWalletSyncController = multichainAssembly.walletSyncController
        let tronWalletMigration = dependencies.keeperCoreRootAssembly.mainAssembly().tronUSDTAssembly.walletMigration()
        let shouldEnrichStartupMultichainWallets = multichainWalletEnricher.needsStartupEnrichment
        let shouldSyncStartupMultichainWallets = multichainWalletSyncController.needsStartupSync

        if shouldEnrichStartupMultichainWallets {
            await multichainWalletEnricher.enrichMissingWallets(passcode: passcode)
        }
        if shouldEnrichStartupMultichainWallets || shouldSyncStartupMultichainWallets {
            await multichainWalletSyncController.syncPendingWallets(passcode: passcode)
            // Wallets only become notifiable once the backend has them bound.
            pushNotificationsManager.refreshSubscriptions()
        }
        // Synced wallets created before app-key persistence still need a one-shot warm; sync above
        // does not touch `.synced`, so this runs whenever a passcode is already in hand.
        await multichainWalletSyncController.warmMissingAppKeys(passcode: passcode)
        if tronWalletMigration.needsMigration {
            await tronWalletMigration.migrate(passcode: passcode)
        }

        let tonProofMnemonics: [String: CoreMnemonic]
        do {
            tonProofMnemonics = try await mnemonicAccess.getMnemonics(
                wallets: missedTonProofWallets,
                passcode: passcode
            )
        } catch {
            Log.e("🪵 failed to load mnemonics for TonProof startup refresh: \(error)")
            tonProofMnemonics = [:]
        }
        for wallet in missedTonProofWallets {
            do {
                guard let mnemonic = tonProofMnemonics[wallet.id] else {
                    Log.e("🪵 failed to load mnemonic for TonProof (v2): missing mnemonic for wallet=\(wallet.id)")
                    continue
                }
                let keyPair = try mnemonic.toKeyPair()
                let pair = WalletPrivateKeyPair(
                    wallet: wallet,
                    privateKey: keyPair.privateKey
                )
                await tonProofTokenService.loadTokensFor(pairs: [pair])
            } catch {
                Log.e("🪵 failed to load mnemonic for TonProof (v2): \(error)")
                continue
            }
        }
    }

    private func showPasscode(
        validator: PasscodeInputValidator,
        completion: ((String) -> Void)?
    ) {
        let router = NavigationControllerRouter(rootViewController: TKNavigationController())

        let securityStore = dependencies.keeperCoreRootAssembly.storesAssembly.securityStore
        let passcodeBiometry = PasscodeBiometryProvider(
            biometryProvider: BiometryProvider(),
            securityStore: securityStore
        )
        let coordinator = PasscodeInputCoordinator(
            router: router,
            context: .entry,
            validator: validator,
            biometryProvider: passcodeBiometry,
            securityStore: securityStore,
            bruteForceController: PasscodeBruteForceController(
                securityStore: securityStore,
                analyticsProvider: dependencies.coreAssembly.analyticsProvider,
                from: .unlock
            )
        )

        coordinator.didInputPasscode = { [weak self, weak coordinator] passcode in
            self?.removeChild(coordinator)
            completion?(passcode)
        }

        coordinator.didLogout = { [dependencies, weak coordinator] in
            guard let coordinator else { return }
            let deleteController = dependencies.keeperCoreRootAssembly.mainAssembly().walletDeleteController
            Task {
                await deleteController.deleteAll()
                await MainActor.run {
                    self.removeChild(coordinator)
                }
            }
        }

        coordinator.start()
        addChild(coordinator)

        showViewController(coordinator.router.rootViewController, animated: false)
    }
}

private extension RootCoordinator {
    func handleStateUpdate(state: RootCoordinatorStateManager.State, deeplink: CoordinatorDeeplink? = nil) {
        removeChild(mainCoordinator)
        removeChild(onboardingCoordinator)
        self.mainCoordinator = nil
        self.onboardingCoordinator = nil
        switch state {
        case .onboarding:
            openOnboarding(deeplink: deeplink)
        case .main:
            openMain(deeplink: deeplink)
        }
    }

    func openOnboarding(deeplink: CoordinatorDeeplink?) {
        resolveRaffleUserIfNeeded()
        let module = OnboardingModule(
            dependencies: OnboardingModule.Dependencies(
                coreAssembly: dependencies.coreAssembly,
                keeperCoreOnboardingAssembly: dependencies.keeperCoreRootAssembly.onboardingAssembly(),
                keeperCoreMainAssembly: dependencies.keeperCoreRootAssembly.mainAssembly(),
                multichainAssembly: dependencies.keeperCoreRootAssembly.mainAssembly().multichainAssembly,
                configurationAssembly: dependencies.keeperCoreRootAssembly.mainAssembly().configurationAssembly
            )
        )
        let coordinator = module.createOnboardingCoordinator()

        coordinator.didFinishOnboarding = { [weak self, weak coordinator] in
            guard let self else { return }
            if let coordinator {
                removeChild(coordinator)
            }
            onboardingCoordinator = nil

            if stateManager.state == .main, mainCoordinator == nil {
                handleStateUpdate(state: .main, deeplink: deeplink)
            }

            let reachabilityTracker = dependencies.coreAssembly.reachabilityTracker
            ToastPresenter.showNoInternetConnectionToastIfNeeded {
                reachabilityTracker.state == .noInternetConnection
            }
        }

        self.onboardingCoordinator = coordinator

        addChild(coordinator)
        coordinator.start(deeplink: deeplink)

        showViewController(coordinator.router.rootViewController, animated: true)
    }

    func openMain(deeplink: CoordinatorDeeplink?) {
        let module = MainModule(
            dependencies: MainModule.Dependencies(
                coreAssembly: dependencies.coreAssembly,
                keeperCoreMainAssembly: dependencies.keeperCoreRootAssembly.mainAssembly(),
                depositPendingTracker: depositPendingTracker
            )
        )
        let coordinator = module.createMainCoordinator()
        self.mainCoordinator = coordinator

        addChild(coordinator)
        coordinator.start(deeplink: deeplink)

        let navigationController = TKNavigationController(rootViewController: coordinator.router.rootViewController)
        navigationController.configureDefaultAppearance()

        showViewController(navigationController, animated: true)
        Task {
            await argon2DeriveTimeMeasurementController.runInBackgroundIfNeeded()
        }
    }

    func resolveRaffleUserIfNeeded() {
        let settings = dependencies.coreAssembly.tkAppSettings
        guard settings.raffleIsNewUser == nil else { return }
        let wallets = dependencies.keeperCoreRootAssembly.storesAssembly.walletsStore.wallets
        settings.raffleIsNewUser = wallets.isEmpty || wallets.allSatisfy(\.isMultichain)
    }

    func handleMigrationResult(
        _ result: MergeMigration.MigrationResult,
        completion: @escaping (_ isSuccess: Bool) -> Void
    ) {
        let title: String
        var description: String
        switch result {
        case let .failedMigrateMnemonics(error):
            title = "Migration failed"
            description = "Failed migrate mnemonics \(error.localizedDescription)"
            completion(false)
        case let .failedMigrateWallets(error):
            title = "Migration failed"
            description = "Failed migrate wallets \(error.localizedDescription)"
            completion(false)
        case let .partialy(failedWallets):
            title = "Failed migrate some wallets"
            description = failedWallets.map { "Name: \($0.name)\nType: \($0.type), \nPublicKey: \($0.pubkey)" }.joined(separator: "\n\n")
            completion(true)
        case .success:
            completion(true)
            return
        }

        description += "\n\n Your seed phrases are safe!"

        let alertController = UIAlertController(
            title: title,
            message: description,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "OK", style: .default))

        router.rootViewController.topPresentedViewController().present(alertController, animated: true)
    }

    func migrateBiometryIfNeed(completion: @escaping () -> Void) {
        let storesAssembly = dependencies.keeperCoreRootAssembly.storesAssembly
        let securityStore = storesAssembly.securityStore
        let mnemonicAccess = dependencies.keeperCoreRootAssembly.secureAssembly.mnemonicAccess

        let biometryEnabled = securityStore.getState().isBiometryEnable
        guard biometryEnabled else {
            return completion()
        }
        // Keep biometry while there is anything it can unlock, judged from two
        // independent signals so neither failure mode disables it spuriously:
        //  • a mnemonic-backed (regular) wallet in metadata — keychain-free, so a
        //    transient keychain failure (a background launch before first unlock
        //    returns errSecInteractionNotAllowed, or a biometryCurrentSet item
        //    invalidated by an enrollment change reads as missing) is never
        //    mistaken for "no wallet" and never persistently disables biometry;
        //  • mnemonics present in the keychain — covers any other mnemonic-backed
        //    kind (e.g. lockup) that the regular-wallet metadata check would miss.
        // Only disable when BOTH say there is genuinely nothing to unlock. The
        // passcode cache is recreatable and is re-saved on the next passcode entry.
        let hasMnemonicWallet = storesAssembly.walletsStore.wallets.contains { $0.kind == .regular }
        let hasStoredMnemonics = mnemonicAccess.hasMnemonics()
        let hasNothingToUnlock = !hasMnemonicWallet && !hasStoredMnemonics
        // Independent second reason: the biometry cache is gone from every storage,
        // marker included, so it was discarded rather than invalidated by an
        // enrollment change — a storage-version rollback drops it, since the
        // passcode lives in the storage being switched away from. Turn biometry off
        // silently: a "biometry changed" notice would be wrong, and the biometry
        // button could only fail. The user re-enables it in settings.
        let isBiometryCacheDiscarded = mnemonicAccess.isBiometryCacheDiscarded()
        guard hasNothingToUnlock || isBiometryCacheDiscarded else {
            return completion()
        }
        securityStore.setIsBiometryEnable(false) { _ in
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    func migrateNativeIfNeed(
        completion: @escaping (_ didNeedToMigrate: Bool, _ isSuccess: Bool, _ passcode: String?) -> Void
    ) {
        let secureAssembly = dependencies.keeperCoreRootAssembly.secureAssembly
        let mergeMigration = MergeMigration(
            asyncStorage: dependencies.keeperCoreRootAssembly.rnAssembly.rnAsyncStorage,
            appInfoProvider: dependencies.coreAssembly.appInfoProvider,
            mnemonicsAccess: secureAssembly.mnemonicAccess,
            keeperInfoRepository: dependencies.keeperCoreRootAssembly.repositoriesAssembly.keeperInfoRepository(),
            keeperInfoStore: dependencies.keeperCoreRootAssembly.storesAssembly.keeperInfoStore,
            securityStore: dependencies.keeperCoreRootAssembly.storesAssembly.securityStore,
            tonProofTokenService: dependencies.keeperCoreRootAssembly.servicesAssembly.tonProofTokenService()
        )

        switch mergeMigration.currentMnemonicsMigrationCheck() {
        case .ready:
            completion(false, true, nil)
            return

        case let .needsMigration(currentVersion):
            final class PasscodeBox {
                var value: String?
            }
            let passcodeBox = PasscodeBox()
            mergeMigration.performNativeMigration(from: currentVersion) { [weak self] handler in
                guard let self else { return }
                showPasscode(validator: handler.validator) { passcode in
                    passcodeBox.value = passcode
                    handler.onSuccess(passcode)
                }
            } completion: { [weak self] result in
                self?.handleMigrationResult(result, completion: { isSuccess in
                    completion(true, isSuccess, passcodeBox.value)
                })
            }

        case let .blocked(error):
            handleMigrationResult(.failedMigrateMnemonics(error: error)) { isSuccess in
                completion(true, isSuccess, nil)
            }
        }
    }

    func migrateRNIfNeed(
        deeplink: CoordinatorDeeplink?,
        completion: @escaping (_ isSuccess: Bool, _ passcode: String?) -> Void
    ) {
        final class PasscodeBox {
            var value: String?
        }
        let passcodeBox = PasscodeBox()
        let mergeMigration = MergeMigration(
            asyncStorage: dependencies.keeperCoreRootAssembly.rnAssembly.rnAsyncStorage,
            appInfoProvider: dependencies.coreAssembly.appInfoProvider,
            mnemonicsAccess: dependencies.keeperCoreRootAssembly.secureAssembly.mnemonicAccess,
            keeperInfoRepository: dependencies.keeperCoreRootAssembly.repositoriesAssembly.keeperInfoRepository(),
            keeperInfoStore: dependencies.keeperCoreRootAssembly.storesAssembly.keeperInfoStore,
            securityStore: dependencies.keeperCoreRootAssembly.storesAssembly.securityStore,
            tonProofTokenService: dependencies.keeperCoreRootAssembly.servicesAssembly.tonProofTokenService()
        )

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard await mergeMigration.isNeedToMigrateFromRN() else {
                openOnboarding(deeplink: deeplink)
                return
            }

            let result = await mergeMigration.performRNMigration { [weak self] handler in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.showPasscode(validator: handler.validator) { passcode in
                        passcodeBox.value = passcode
                        handler.onSuccess(passcode)
                    }
                }
            }
            handleMigrationResult(result) { isSuccess in
                completion(isSuccess, passcodeBox.value)
            }
        }
    }

    func showViewController(_ viewController: UIViewController, animated: Bool) {
        activeViewController?.willMove(toParent: nil)
        activeViewController?.view.removeFromSuperview()
        activeViewController?.removeFromParent()

        activeViewController = viewController

        router.rootViewController.addChild(viewController)
        router.rootViewController.view.addSubview(viewController.view)
        viewController.didMove(toParent: router.rootViewController)

        viewController.view.snp.makeConstraints { make in
            make.edges.equalTo(router.rootViewController.view)
        }

        if animated {
            UIView.transition(with: router.rootViewController.view, duration: 0.2, options: .transitionCrossDissolve) {}
        }
    }

    func sendFirstLaunchAnalyticsEvent() {
        let analyticsProvider = dependencies.coreAssembly.analyticsProvider
        let appSettings = dependencies.coreAssembly.appSettings

        let firstLaunchTimestamp = appSettings.firstLaunchDate
        guard firstLaunchTimestamp == nil else { return }
        appSettings.firstLaunchDate = Date()

        analyticsProvider.log(InstallApp())
    }
}

extension KeeperCore.Deeplink: TKCoordinator.CoordinatorDeeplink {}
extension String: TKCoordinator.CoordinatorDeeplink {}
