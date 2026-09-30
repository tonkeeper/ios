import KeeperCore
import KeeperCoreComponents
import Stories
import SwiftUI
import TKAppInfo
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLocalize
import TKLogging
import TKStories
import TKUIKit
import UIKit
import WalletExtensions

final class SettingsCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didTapBattery: ((Wallet) -> Void)?
    var didTapSupport: (() -> Void)?
    var didRequestOpenMerchantURL: ((URL, UIViewController) -> Void)?
    var didRequestImportTestnetWallet: (() -> Void)?

    private let wallet: Wallet
    private let inAppReviewService: InAppReviewService
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private let depositPendingTracker: DepositPendingTracker

    init(
        wallet: Wallet,
        inAppReviewService: InAppReviewService,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter,
        depositPendingTracker: DepositPendingTracker
    ) {
        self.wallet = wallet
        self.inAppReviewService = inAppReviewService
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        self.depositPendingTracker = depositPendingTracker
        super.init(router: router)
    }

    override func start() {
        openSettingsRoot()
    }
}

private extension SettingsCoordinator {
    func presentAlertController(title: String, message: String?, actions: [UIAlertAction]) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        actions.forEach { action in alertController.addAction(action) }
        router.rootViewController.present(alertController, animated: true)
    }

    func openSettingsRoot() {
        let configurator = SettingsListRootConfigurator(
            wallet: keeperCoreMainAssembly.storesAssembly.walletsStore.getWallet(id: wallet.id) ?? wallet,
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            mnemonicsAccess: keeperCoreMainAssembly.secureAssembly.mnemonicAccess,
            inAppReviewService: inAppReviewService,
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
            walletDeleteController: keeperCoreMainAssembly.walletDeleteController,
            anaylticsProvider: coreAssembly.analyticsProvider,
            walletNotificationStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
            settingsRepository: keeperCoreMainAssembly.repositoriesAssembly.settingsRepository()
        )

        configurator.didOpenURL = { [coreAssembly] in
            coreAssembly.urlOpener().open(url: $0)
        }

        configurator.didShowAlert = { [weak self] title, description, actions in
            self?.presentAlertController(title: title, message: description, actions: actions)
        }

        configurator.didTapEditWallet = { [weak self] wallet in
            self?.openEditWallet(wallet: wallet)
        }

        configurator.didTapCurrencySettings = { [weak self] in
            self?.openCurrencyPicker()
        }

        configurator.didTapSecuritySettings = { [weak self] in
            self?.openSecurity()
        }

        configurator.didTapLegal = { [weak self] in
            self?.openLegal()
        }

        configurator.didTapSupport = { [weak self] in
            self?.didTapSupport?()
        }

        configurator.didTapLanguage = { [weak self] in
            self?.openNativeSettings()
        }

        configurator.didTapBackup = { [weak self] wallet in
            self?.openBackup(wallet: wallet)
        }

        configurator.didTapSignOutRegularWallet = { [weak self] wallet in
            self?.deleteRegular(wallet: wallet, isSignOut: true)
        }

        configurator.didTapDeleteRegularWallet = { [weak self] wallet in
            self?.deleteRegular(wallet: wallet, isSignOut: false)
        }

        configurator.didTapNotifications = { [weak self] wallet in
            self?.openNotifications(wallet: wallet)
        }

        configurator.didTapW5Wallet = { [weak self] wallet in
            self?.openW5Story(wallet: wallet)
        }

        configurator.didTapV4Wallet = { [weak self] wallet in
            self?.addV4Wallet(wallet: wallet)
        }

        configurator.didTapBattery = { [weak self] wallet in
            self?.didTapBattery?(wallet)
        }

        configurator.didTapConnectedApps = { [weak self] wallet in
            self?.openConnectedApps(wallet: wallet)
        }

        configurator.didTapMigration = { [weak self] wallet in
            self?.openMigration(wallet: wallet)
        }

        configurator.didDeleteWallet = { [weak self] in
            guard let self else { return }
            let wallets = self.keeperCoreMainAssembly.storesAssembly.walletsStore.wallets
            if !wallets.isEmpty {
                self.router.pop(animated: true)
            }
        }

        let module = SettingsListAssembly.module(configurator: configurator)

        module.viewModel.didOpenDevMenu = { [weak self] in
            self?.openDevMenu()
        }

        module.viewModel.didRequestClose = { [weak self] in
            self?.router.pop(animated: true)
        }

        router.push(
            viewController: module.viewController,
            onPopClosures: { [weak self] in
                self?.didFinish?(self)
            }
        )
    }

    func openEditWallet(wallet: Wallet) {
        let addWalletModuleModule = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
                storesAssembly: keeperCoreMainAssembly.storesAssembly,
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                multichainAssembly: keeperCoreMainAssembly.multichainAssembly,
                scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
                configurationAssembly: keeperCoreMainAssembly.configurationAssembly
            )
        )

        let module = addWalletModuleModule.createCustomizeWalletModule(
            name: wallet.label,
            tintColor: wallet.tintColor,
            icon: wallet.metaData.icon,
            configurator: EditWalletCustomizeWalletViewModelConfigurator()
        )

        module.output.didCustomizeWallet = { [weak self] model in
            self?.updateWallet(wallet: wallet, model: model)
        }

        let navigationController = TKNavigationController(rootViewController: module.view)

        module.view.setupHeaderRightCloseButton { [weak navigationController] in
            navigationController?.dismiss(animated: true)
        }

        router.present(navigationController)
    }

    func didTapAddW5Wallet(wallet: Wallet) {
        let coordinator = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
                storesAssembly: keeperCoreMainAssembly.storesAssembly,
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                multichainAssembly: keeperCoreMainAssembly.multichainAssembly,
                scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
                configurationAssembly: keeperCoreMainAssembly.configurationAssembly
            )
        ).createAddDifferentRevisionWalletCoordinator(
            wallet: wallet,
            revisionToAdd: .v5R1,
            router: ViewControllerRouter(rootViewController: router.rootViewController)
        )

        coordinator.didAddedWallet = { [weak self] in
            self?.router.pop(animated: true)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openW5Story(wallet: Wallet) {
        let storiesViewController = TKStoriesFactory.storiesViewController(
            models: [
                StoriesPageModel(
                    title: TKLocales.W5Stories.Gasless.title,
                    description: TKLocales.W5Stories.Gasless.subtitle,
                    backgroundImage: .image(.TKUIKit.Artwork.Stories.gasless)
                ),
                StoriesPageModel(
                    title: TKLocales.W5Stories.Messages.title,
                    description: TKLocales.W5Stories.Messages.subtitle,
                    backgroundImage: .image(.TKUIKit.Artwork.Stories.messages)
                ),
                StoriesPageModel(
                    title: TKLocales.W5Stories.Phrase.title,
                    description: TKLocales.W5Stories.Phrase.subtitle,
                    button: StoriesPageModel.Button(
                        title: TKLocales.W5Stories.Phrase.button,
                        action: { [weak self] in
                            self?.router.dismiss(animated: true, completion: {
                                self?.didTapAddW5Wallet(wallet: wallet)
                            })
                        }
                    ),
                    backgroundImage: .image(.TKUIKit.Artwork.Stories.phrase)
                ),
            ]
        )
        router.present(storiesViewController)
    }

    func addV4Wallet(wallet: Wallet) {
        let coordinator = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
                storesAssembly: keeperCoreMainAssembly.storesAssembly,
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                multichainAssembly: keeperCoreMainAssembly.multichainAssembly,
                scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
                configurationAssembly: keeperCoreMainAssembly.configurationAssembly
            )
        ).createAddDifferentRevisionWalletCoordinator(
            wallet: wallet,
            revisionToAdd: .v4R2,
            router: ViewControllerRouter(
                rootViewController: router.rootViewController
            )
        )

        coordinator.didAddedWallet = { [weak self] in
            self?.router.pop(animated: true)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func updateWallet(wallet: Wallet, model: CustomizeWalletModel) {
        let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore
        Task {
            await walletsStore.updateWalletMetaData(
                wallet,
                metaData: WalletMetaData(customizeWalletModel: model)
            )
        }
    }

    func openCurrencyPicker() {
        let configuration = SettingsListCurrencyPickerConfigurator(
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration
        )
        configuration.didSelect = { [weak self] in
            self?.router.pop()
        }
        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewModel.didRequestClose = { [weak self] in
            self?.router.pop(animated: true)
        }

        router.push(viewController: module.viewController)
    }

    func openBackup(wallet: Wallet) {
        let configuration = SettingsListBackupConfigurator(
            wallet: wallet,
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            processedBalanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )

        configuration.didTapBackupManually = { [weak self] in
            self?.openManuallyBackup(wallet: wallet)
        }

        configuration.didTapShowRecoveryPhrase = { [weak self] in
            self?.openRecoveryPhrase(wallet: wallet)
        }

        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewModel.didRequestClose = { [weak self] in
            self?.router.pop(animated: true)
        }

        router.push(viewController: module.viewController)
    }

    func openSecurity() {
        let configuration = SettingsListSecurityConfigurator(
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
            mnemonicsAccess: keeperCoreMainAssembly.secureAssembly.mnemonicAccess,
            biometryProvider: BiometryProvider()
        )

        configuration.didRequirePasscode = { [weak self] in
            await self?.getPasscode()
        }

        configuration.didTapChangePasscode = { [openChangePasscode] in
            openChangePasscode()
        }

        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewModel.didRequestClose = { [weak self] in
            self?.router.pop(animated: true)
        }

        router.push(viewController: module.viewController)
    }

    func openRecoveryPhrase(wallet: Wallet) {
        let coordinator = SettingsRecoveryPhraseCoordinator(
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: router
        )

        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openManuallyBackup(wallet: Wallet) {
        let coordinator = BackupModule(
            dependencies: BackupModule.Dependencies(
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                coreAssembly: coreAssembly
            )
        ).createBackupCoordinator(
            router: router,
            wallet: wallet,
            source: .settings
        )

        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openChangePasscode() {
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()

        let coordinator = PasscodeChangeCoordinator(
            router: NavigationControllerRouter(
                rootViewController: navigationController
            ),
            keeperCoreAssembly: keeperCoreMainAssembly,
            analyticsProvider: coreAssembly.analyticsProvider
        )

        coordinator.didCancel = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
            self?.router.dismiss(animated: true)
        }

        coordinator.didChangePasscode = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
            self?.router.dismiss(animated: true)
        }

        addChild(coordinator)
        coordinator.start()

        router.present(
            coordinator.router.rootViewController,
            onDismiss: { [weak self, weak coordinator] in
                guard let coordinator else { return }
                self?.removeChild(coordinator)
            }
        )
    }

    func deleteRegular(wallet: Wallet, isSignOut: Bool) {
        let walletIcon: SwiftUI.Image?
        let walletName: String
        switch wallet.icon {
        case let .emoji(emoji):
            walletIcon = nil
            walletName = "\(emoji) \(wallet.label)"
        case let .icon(image):
            walletIcon = image.swiftUIImage
            walletName = wallet.label
        }
        PopupContentPresenter.present(
            from: router.rootViewController
        ) { dismisser in
            SettingsDeleteWarningView(
                title: isSignOut ? TKLocales.SignOutWarning.title : TKLocales.DeleteWalletWarning.title,
                caption: isSignOut ? TKLocales.SignOutWarning.caption : TKLocales.DeleteWalletWarning.caption,
                buttonTitle: isSignOut ? TKLocales.Actions.signOut : TKLocales.DeleteWalletWarning.button,
                walletIcon: walletIcon,
                walletName: walletName,
                onSignOut: { [weak self] in
                    dismisser.dismiss {
                        guard let self else { return }
                        Task {
                            guard let passcode = await self.getPasscode() else { return }
                            await self.keeperCoreMainAssembly.storesAssembly.walletNotificationStore.setNotificationIsOn(false, wallet: wallet)
                            await self.keeperCoreMainAssembly.walletDeleteController.deleteWallet(wallet: wallet, passcode: passcode)
                            await MainActor.run {
                                let wallets = self.keeperCoreMainAssembly.storesAssembly.walletsStore.wallets
                                if !wallets.isEmpty {
                                    self.router.pop(animated: true)
                                }
                            }
                        }
                    }
                },
                onBackup: { [weak self] in
                    dismisser.dismiss {
                        if wallet.isBackupAvailable {
                            if wallet.hasBackup {
                                self?.openRecoveryPhrase(wallet: wallet)
                            } else {
                                self?.openManuallyBackup(wallet: wallet)
                            }
                        }
                    }
                }
            )
        }
    }

    func openNativeSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        Log.d("open settings URL: \(url)")
        UIApplication.shared.open(url)
    }

    func openLegal() {
        let configuration = SettingsListLegalConfigurator()

        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewModel.didRequestClose = { [weak self] in
            self?.router.pop(animated: true)
        }

        configuration.openUrl = { [coreAssembly] url in
            coreAssembly.urlOpener().open(url: url)
        }

        router.push(viewController: module.viewController)
    }

    func openNotifications(wallet: Wallet) {
        let configuration = SettingsListNotificationsConfigurator(
            wallet: wallet,
            walletNotificationStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
            notificationsService: keeperCoreMainAssembly.servicesAssembly.notificationsService(
                walletNotificationsStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
                tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
            ),
            tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore,
            urlOpener: coreAssembly.urlOpener(),
            pushTokenProvider: PushNotificationTokenProvider(),
            appSettings: coreAssembly.appSettings
        )

        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewModel.didRequestClose = { [weak self] in
            self?.router.pop(animated: true)
        }

        router.push(viewController: module.viewController)
    }

    func getPasscode() async -> String? {
        let mnemonicAccess = keeperCoreMainAssembly.mnemonicAccess
        return await PasscodeInputCoordinator.getPasscode(
            parentCoordinator: self,
            parentRouter: router,
            mnemonicAccess: mnemonicAccess,
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
            analyticsProvider: coreAssembly.analyticsProvider
        )
    }

    func getRNPasscode() async -> String? {
        return await PasscodeInputCoordinator.getPasscode(
            parentCoordinator: self,
            parentRouter: router,
            validator: PasscodeLegacyConfirmationValidator(
                mnemonicsRepository: keeperCoreMainAssembly.secureAssembly
                    .mnemonicAccess
                    .legacyRepository
                    .rn
            ),
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
            analyticsProvider: coreAssembly.analyticsProvider
        )
    }

    func openConnectedApps(wallet: Wallet) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            let tonConnectAppsStore = keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
            let connectedAppsStore = keeperCoreMainAssembly.storesAssembly.connectedAppsStore(
                tonConnectAppsStore: tonConnectAppsStore
            )
            let walletConnectService = await keeperCoreMainAssembly.walletConnectAssembly.walletConnectService
            let walletConnectSessionsStore = keeperCoreMainAssembly.storesAssembly.walletConnectSessionsStore(
                walletConnectService: walletConnectService
            )

            let viewModel = SettingsConnectedAppsViewModel(
                wallet: wallet,
                connectedAppsStore: connectedAppsStore,
                tonConnectConnectionMetadataStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectConnectionMetadataStore,
                walletConnectSessionsStore: walletConnectSessionsStore,
                notificationsService: keeperCoreMainAssembly.servicesAssembly.notificationsService(
                    walletNotificationsStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
                    tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
                ),
                pushTokenProvider: PushNotificationTokenProvider(),
                dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter
            )
            let viewController = SettingsConnectedAppsHostingViewController(viewModel: viewModel)

            viewModel.didRequestClose = { [weak self] in
                self?.router.pop(animated: true)
            }
            viewModel.didRequestShowAlert = { [weak self] message in
                self?.presentAlertController(
                    title: message,
                    message: nil,
                    actions: [
                        UIAlertAction(
                            title: TKLocales.Actions.ok,
                            style: .default,
                            handler: nil
                        ),
                    ]
                )
            }
            viewModel.didRequestShowDisconnectConfirmation = { [weak viewController] configuration, disconnect in
                guard let viewController else { return }

                WalletConnectConfirmationPresenter.present(
                    configuration: configuration,
                    from: viewController.topPresentedViewController(),
                    primaryAction: disconnect
                )
            }

            router.push(viewController: viewController)
        }
    }

    func openMigration(wallet: Wallet, onFinish: (() -> Void)? = nil) {
        let coordinator = WalletMigrationCoordinator(
            wallet: wallet,
            source: .settings,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: router,
            depositPendingTracker: depositPendingTracker
        )
        coordinator.didRequestOpenMerchantURL = { [weak self] url, fromViewController in
            self?.didRequestOpenMerchantURL?(url, fromViewController)
        }
        addChild(coordinator)
        coordinator.didFinish = { [weak self, weak coordinator] _ in
            self?.removeChild(coordinator)
            onFinish?()
        }
        coordinator.start()
    }

    func openDevMenu() {
        let storiesAssembly = Stories.Assembly(
            keeperCoreAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )
        let configuration = SettingsListDevMenuConfigurator(
            uniqueIdProvider: coreAssembly.uniqueIdProvider,
            storiesService: storiesAssembly.storiesService(),
            homeBannersStore: keeperCoreMainAssembly.storesAssembly.homeBannersStore,
            appInfoProvider: coreAssembly.appInfoProvider,
            featureFlags: coreAssembly.featureFlags,
            tkAppSettings: coreAssembly.tkAppSettings
        )
        configuration.didSelectExportLogs = { [weak self] in
            self?.exportLogs()
        }
        configuration.didSelectImportTestnetWallet = { [weak self] in
            self?.didRequestImportTestnetWallet?()
        }
        configuration.didSelectRNSeedPhrasesRecovery = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self,
                      let passcode = await self.getRNPasscode() else { return }
                let mnemonicsAccess = keeperCoreMainAssembly.secureAssembly.mnemonicAccess
                let mnemonicsVault = mnemonicsAccess.legacyRepository.rn
                guard let mnemonics = try? await mnemonicsVault.getMnemonics(password: passcode) else {
                    return
                }
                self.openSeedPhrases(mnemonics: mnemonics)
            }
        }
        configuration.didSelectSeedPhrasesRecovery = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self,
                      let passcode = await self.getPasscode() else { return }
                let mnemonicsAccess = keeperCoreMainAssembly.secureAssembly.mnemonicAccess
                let mnemonicsVault = mnemonicsAccess.legacyRepository.native
                do {
                    let mnemonics = try await mnemonicsVault.getMnemonics(password: passcode)
                    self.openSeedPhrases(mnemonics: mnemonics)
                } catch {
                    Log.e("🪵 failed to load legacy mnemonics in dev menu: \(error)")
                }
            }
        }
        configuration.didSelectStoreCountryCode = { [weak self] completion in
            self?.openStoreCountryCodeInput(completion: completion)
        }
        configuration.didSelectDeviceCountryCode = { [weak self] completion in
            self?.openDeviceCountryCodeInput(completion: completion)
        }
        configuration.didSelectBuildVersion = { [weak self] completion in
            self?.openBuildVersionInput(completion: completion)
        }
        configuration.didSelectFeatureFlags = { [weak self] in
            self?.openFeatureFlags()
        }
        configuration.didSelectTooltips = { [weak self] in
            self?.openTooltips()
        }
        configuration.didSelectDesignSystem = { [weak self] in
            self?.openDesignSystem()
        }
        configuration.didSelectToastTesting = { [weak self] in
            self?.openToastTesting()
        }
        configuration.didSelectMysteryRaffle = { [weak self] in
            self?.openMysteryRaffleDebug()
        }

        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewModel.didRequestClose = { [weak self] in
            self?.router.pop(animated: true)
        }

        router.push(viewController: module.viewController)
    }

    func openFeatureFlags() {
        let configuration = SettingsListFeatureFlagsConfigurator(
            featureFlags: coreAssembly.featureFlags,
            configurationAssembly: keeperCoreMainAssembly.configurationAssembly
        )
        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewModel.didRequestClose = { [weak self] in
            self?.router.pop(animated: true)
        }
        router.push(viewController: module.viewController)
    }

    func openTooltips() {
        let configuration = SettingsListTooltipsConfigurator(
            commonTooltipSettings: coreAssembly.tooltipsAssembly.commonDataRepository,
            tooltipOverrides: coreAssembly.tooltipsAssembly.overrides,
            withdrawTooltipSettings: coreAssembly.tooltipsAssembly.withdrawButtonRepository,
            newHistoryEntryPointTooltipSettings: coreAssembly.tooltipsAssembly.newHistoryEntryPointRepository,
            tradeTabTooltipSettings: coreAssembly.tooltipsAssembly.tradeTabRepository,
            favoriteTooltipSettings: coreAssembly.tooltipsAssembly.favoriteRepository,
            addMultichainWalletTooltipSettings: coreAssembly.tooltipsAssembly.addMultichainWalletRepository
        )
        configuration.didSelectFirstLaunchDate = { [weak self] selectedDate, completion in
            self?.presentTooltipFirstLaunchDatePicker(selectedDate: selectedDate, completion: completion)
        }
        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewModel.didRequestClose = { [weak self] in
            self?.router.pop(animated: true)
        }
        router.push(viewController: module.viewController)
    }

    func openDesignSystem() {
        let configuration = SettingsListDesignSystemConfigurator()
        configuration.didSelectCellsCatalog = { [weak self] in
            self?.openCellsCatalog()
        }
        configuration.didSelectTransactionCellPreviews = { [weak self] in
            self?.openTransactionCellPreviews()
        }
        configuration.didSelectNFTCardPreviews = { [weak self] in
            self?.openNFTCardPreviews()
        }
        configuration.didSelectIconButtonViewPreviews = { [weak self] in
            self?.openIconButtonViewPreviews()
        }
        configuration.didSelectWalletButtonPreviews = { [weak self] in
            self?.openWalletButtonPreviews()
        }
        configuration.didSelectBatterySwiftUIViewPreviews = { [weak self] in
            self?.openBatterySwiftUIViewPreviews()
        }
        configuration.didSelectNotificationBannerPreviews = { [weak self] in
            self?.openNotificationBannerPreviews()
        }
        configuration.didSelectButtonViewPreviews = { [weak self] in
            self?.openButtonViewPreviews()
        }
        configuration.didSelectModalCardHeaderPreviews = { [weak self] in
            self?.openModalCardHeaderPreviews()
        }
        configuration.didSelectListTitleViewPreviews = { [weak self] in
            self?.openListTitleViewPreviews()
        }
        configuration.didSelectTabCategoriesViewPreviews = { [weak self] in
            self?.openTabCategoriesViewPreviews()
        }
        configuration.didSelectPlaceholderViewPreviews = { [weak self] in
            self?.openPlaceholderViewPreviews()
        }
        configuration.didSelectChartPreviews = { [weak self] in
            self?.openChartPreviews()
        }
        configuration.didSelectCircularLoaderPreviews = { [weak self] in
            self?.openCircularLoaderPreviews()
        }
        configuration.didSelectColorsPreviews = { [weak self] in
            self?.openColorsPreviews()
        }

        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewModel.didRequestClose = { [weak self] in
            self?.router.pop(animated: true)
        }
        router.push(viewController: module.viewController)
    }

    func openToastTesting() {
        let configuration = SettingsListToastTestingConfigurator()
        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewModel.didRequestClose = { [weak self] in
            self?.router.pop(animated: true)
        }
        router.push(viewController: module.viewController)
    }

    func openMysteryRaffleDebug() {
        let viewModel = MysteryRaffleDebugViewModel(
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            appSettings: coreAssembly.tkAppSettings
        )
        let view = MysteryRaffleDebugView(
            viewModel: viewModel,
            onSelectState: { [weak self] content in
                guard let self else { return }
                MysteryRaffleCoordinator.presentStub(
                    content: content,
                    rootViewController: router.rootViewController
                )
            },
            onOpenLiveRaffle: { [weak self] raffle in
                guard let self else { return }
                // Presents the loaded raffle directly instead of `presentCurrent`: the dev
                // surface must open whatever it just showed, regardless of the feature flag.
                MysteryRaffleCoordinator.present(
                    raffle: raffle,
                    from: self,
                    rootViewController: router.rootViewController,
                    source: .walletMain,
                    keeperCoreMainAssembly: keeperCoreMainAssembly,
                    coreAssembly: coreAssembly,
                    openMigration: { [weak self] onFinish in
                        guard let self,
                              let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet,
                              wallet.isMultichain
                        else {
                            onFinish()
                            return
                        }
                        self.openMigration(wallet: wallet, onFinish: onFinish)
                    }
                )
            },
            onSelectStory: { [weak self] story in
                guard let self else { return }
                MysteryRaffleCoordinator.presentStory(
                    story,
                    rootViewController: router.rootViewController,
                    keeperCoreMainAssembly: keeperCoreMainAssembly,
                    coreAssembly: coreAssembly,
                    openDeeplink: nil
                )
            },
            onResetShownStories: { [weak self] in
                guard let self else { return }
                MysteryRaffleStoriesRouter
                    .make(keeperCoreMainAssembly: keeperCoreMainAssembly, coreAssembly: coreAssembly)
                    .resetShownStories()
            }
        )
        let viewController = TKHostingController(content: view)
        viewController.title = "Mystery Raffle"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openCellsCatalog() {
        let viewController = SettingsCellsCatalogViewController()
        viewController.title = "Cells"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openTransactionCellPreviews() {
        let viewController = SettingsTransactionCellPreviewsViewController()
        viewController.title = "Transaction Cell"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openNFTCardPreviews() {
        let viewController = SettingsNFTCardPreviewsViewController()
        viewController.title = "NFT Card"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openButtonViewPreviews() {
        let viewController = SettingsButtonViewPreviewsViewController()
        viewController.title = "Button View"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openIconButtonViewPreviews() {
        let viewController = SettingsIconButtonViewPreviewsViewController()
        viewController.title = "Icon Button View"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openWalletButtonPreviews() {
        let viewController = SettingsWalletButtonPreviewsViewController()
        viewController.title = "Wallet Button"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openBatterySwiftUIViewPreviews() {
        let viewController = SettingsBatterySwiftUIViewPreviewsViewController()
        viewController.title = "Battery SwiftUI View"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openNotificationBannerPreviews() {
        let viewController = SettingsNotificationBannerPreviewsViewController()
        viewController.title = "Notification Banner"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openModalCardHeaderPreviews() {
        let viewController = SettingsModalCardHeaderPreviewsViewController()
        viewController.title = "Modal Card Header"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openListTitleViewPreviews() {
        let viewController = SettingsListTitleViewPreviewsViewController()
        viewController.title = "List Title View"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openTabCategoriesViewPreviews() {
        let viewController = SettingsTabCategoriesViewPreviewsViewController()
        viewController.title = "Tab Categories View"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openPlaceholderViewPreviews() {
        let viewController = SettingsPlaceholderViewPreviewsViewController()
        viewController.title = "Placeholder View"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openChartPreviews() {
        let viewController = SettingsChartPreviewsViewController()
        viewController.title = "Chart"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openCircularLoaderPreviews() {
        let viewController = SettingsCircularLoaderPreviewsViewController()
        viewController.title = "Circular Loader"
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openColorsPreviews() {
        let viewController = SettingsColorsPreviewViewController()
        viewController.setupBackButton()
        router.push(viewController: viewController)
    }

    func openSeedPhrases(mnemonics: Mnemonics) {
        let configuration = SettingsListRNWalletsSeedPhrasesConfigurator(
            mnemonics: mnemonics
        )
        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewModel.didRequestClose = { [weak self] in
            self?.router.pop(animated: true)
        }

        router.push(viewController: module.viewController)
    }

    private func exportLogs() {
        ToastPresenter.showToast(configuration: .loading)

        Task {
            do {
                let fileURL = try await Task.detached(priority: .userInitiated) {
                    try LogExporter.exportToTemporaryFile(
                        domain: nil,
                        lastHours: 2,
                        filenamePrefix: "keeper_logs"
                    )
                }.value

                await MainActor.run { [weak self] in
                    ToastPresenter.hideToast()
                    guard let self else { return }
                    let activityViewController = UIActivityViewController(
                        activityItems: [fileURL],
                        applicationActivities: nil
                    )
                    self.router.rootViewController.topPresentedViewController().present(activityViewController, animated: true)
                }
            } catch {
                await MainActor.run { [weak self] in
                    ToastPresenter.hideToast()
                    self?.presentAlertController(
                        title: "Export failed",
                        message: error.localizedDescription,
                        actions: [UIAlertAction(title: "OK", style: .default)]
                    )
                }
            }
        }
    }

    func openStoreCountryCodeInput(completion: @escaping () -> Void) {
        let appInfoProvider = coreAssembly.appInfoProvider

        let alertController = UIAlertController(title: "Store country code", message: nil, preferredStyle: .alert)
        alertController.addTextField { tf in
            tf.text = appInfoProvider.overridenStoreCountryCode
        }
        alertController.addAction(
            UIAlertAction(
                title: "OK",
                style: .default,
                handler: { _ in
                    let input = alertController.textFields?[0].text
                    appInfoProvider.overrideStoreCountryCode(input?.isEmpty == true ? nil : input)
                    completion()
                }
            )
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        router.rootViewController.topPresentedViewController().present(alertController, animated: true)
    }

    func openDeviceCountryCodeInput(completion: @escaping () -> Void) {
        let appInfoProvider = coreAssembly.appInfoProvider

        let alertController = UIAlertController(title: "Device country code", message: nil, preferredStyle: .alert)
        alertController.addTextField { tf in
            tf.text = appInfoProvider.overridenDeviceCountryCode
        }
        alertController.addAction(
            UIAlertAction(
                title: "OK",
                style: .default,
                handler: { _ in
                    let input = alertController.textFields?[0].text
                    appInfoProvider.overrideDeviceCountryCode((input?.isEmpty == true ? nil : input))
                    completion()
                }
            )
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        router.rootViewController.topPresentedViewController().present(alertController, animated: true)
    }

    func openBuildVersionInput(completion: @escaping () -> Void) {
        let appInfoProvider = coreAssembly.appInfoProvider

        let alertController = UIAlertController(title: "Metrics tag", message: nil, preferredStyle: .alert)
        alertController.addTextField { tf in
            tf.text = appInfoProvider.overridenVersion
            tf.placeholder = InfoProvider.appVersion()
        }
        alertController.addAction(
            UIAlertAction(
                title: "OK",
                style: .default,
                handler: { _ in
                    let input = alertController.textFields?[0].text
                    appInfoProvider.overrideVersion(input?.isEmpty == true ? nil : input)
                    completion()
                    ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Restart the app to apply"))
                }
            )
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        router.rootViewController.topPresentedViewController().present(alertController, animated: true)
    }

    func presentTooltipFirstLaunchDatePicker(
        selectedDate: Date,
        completion: @escaping (Date) -> Void
    ) {
        let viewController = TooltipDatePickerViewController(
            selectedDate: selectedDate,
            completion: completion
        )
        let navigationController = TKNavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = .formSheet
        router.rootViewController.topPresentedViewController().present(navigationController, animated: true)
    }
}
