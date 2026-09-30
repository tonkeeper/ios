import KeeperCore
import KeeperCoreComponents
import KeeperCoreSensitive
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKScreenKit
import TKUIKit
import UIKit

final class ImportWalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didCancel: (() -> Void)?
    var didImportWallets: (() -> Void)?

    private let network: Network
    private let analyticsProvider: AnalyticsProvider
    private let walletsUpdateAssembly: WalletsUpdateAssembly
    private let storesAssembly: StoresAssembly
    private let multichainAssembly: MultichainAssembly
    private let configurationAssembly: ConfigurationAssembly
    private let hasPasscodeChecker: HasPasscodeChecker
    private let customizeWalletModule: () -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void>
    private let analyticsContext: WalletFlowAnalyticsContext

    init(
        router: NavigationControllerRouter,
        analyticsProvider: AnalyticsProvider,
        walletsUpdateAssembly: WalletsUpdateAssembly,
        storesAssembly: StoresAssembly,
        hasPasscodeChecker: HasPasscodeChecker,
        multichainAssembly: MultichainAssembly,
        configurationAssembly: ConfigurationAssembly,
        network: Network,
        analyticsContext: WalletFlowAnalyticsContext,
        customizeWalletModule: @escaping () -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void>
    ) {
        self.analyticsProvider = analyticsProvider
        self.walletsUpdateAssembly = walletsUpdateAssembly
        self.storesAssembly = storesAssembly
        self.configurationAssembly = configurationAssembly
        self.multichainAssembly = multichainAssembly
        self.network = network
        self.customizeWalletModule = customizeWalletModule
        self.hasPasscodeChecker = hasPasscodeChecker
        self.analyticsContext = analyticsContext
        super.init(router: router)
    }

    override func start() {
        openRecoveryPhraseInput()
    }
}

private struct WalletImportRequest {
    let mnemonic: CoreMnemonic
    let walletKindPreference: ImportWalletKindPreference
}

private extension ImportWalletCoordinator {
    func openRecoveryPhraseInput() {
        let inputRecoveryPhrase = TKInputRecoveryPhraseAssembly.module(
            title: TKLocales.ImportWallet.title,
            caption: TKLocales.ImportWallet.description,
            set12WordsButtonTitle: TKLocales.ImportWallet.set12Words,
            set24WordsButtonTitle: TKLocales.ImportWallet.set24Words,
            continueButtonTitle: TKLocales.Actions.continueAction,
            pasteButtonTitle: TKLocales.Actions.paste,
            validator: AddWalletInputRecoveryPhraseValidator(),
            suggestsProvider: AddWalletInputRecoveryPhraseSuggestsProvider()
        )

        inputRecoveryPhrase.output.didFailPhraseValidation = { [weak self] phrase in
            guard let self = self else { return }
            let derivationType = resolveDerivationType(phrase: phrase)
            self.analyticsProvider.logWalletImportStarted(
                walletMode: self.analyticsContext.walletMode(for: derivationType),
                walletSource: .mnemonic,
                from: self.analyticsContext.from
            )
            self.analyticsProvider.logWalletImportError(
                walletMode: self.analyticsContext.walletMode(for: derivationType),
                walletSource: .mnemonic,
                from: self.analyticsContext.from,
                errorMessage: TKLocales.ImportWallet.incorrectPhrase
            )
            ToastPresenter.showToast(
                configuration: .defaultConfiguration(text: TKLocales.ImportWallet.incorrectPhrase)
            )
        }

        inputRecoveryPhrase.output.didInputRecoveryPhrase = { [weak self] phrase, completion in
            guard let self = self else { return }
            if isWalletAlreadyImported(phrase: phrase) {
                completion()
                ToastPresenter.showToast(
                    configuration: .defaultConfiguration(text: TKLocales.ImportWallet.alreadyImported)
                )
                return
            }
            if isWalletKindSelectionEnabled {
                loadWalletKindPreviewsIfNeeded(phrase: phrase, completion: completion)
            } else {
                startAutomaticImport(
                    phrase: phrase,
                    derivationType: resolveDerivationType(phrase: phrase),
                    completion: completion
                )
            }
        }

        if router.rootViewController.viewControllers.isEmpty {
            inputRecoveryPhrase.viewController.setupLeftCloseButton { [weak self] in
                self?.didCancel?()
            }
        } else {
            inputRecoveryPhrase.viewController.setupBackButton()
        }

        router.push(
            viewController: inputRecoveryPhrase.viewController,
            animated: true,
            onPopClosures: { [weak self] in
                self?.didCancel?()
            },
            completion: nil
        )
    }

    func detectActiveWallets(
        request: WalletImportRequest,
        completion: @escaping () -> Void,
        onStayOnScreen: (() -> Void)? = nil,
        onForwardNavigation: (() -> Void)? = nil
    ) {
        let mnemonic = request.mnemonic
        analyticsProvider.logWalletImportStarted(
            walletMode: analyticsContext.walletMode(for: mnemonic.type),
            walletSource: .mnemonic,
            from: analyticsContext.from
        )

        Task {
            do {
                let activeWallets = try await walletsUpdateAssembly.walletImportController().findActiveWallets(
                    mnemonic: mnemonic,
                    network: network,
                    checkHistory: mnemonic.type == .bip39soft
                        || configurationAssembly.configuration.featureEnabled(.mnemonicsStorageV2)
                )
                await MainActor.run {
                    completion()
                    let didNavigateForward = handleActiveWallets(
                        request: request,
                        activeWalletModels: activeWallets
                    )
                    if didNavigateForward {
                        onForwardNavigation?()
                    } else {
                        onStayOnScreen?()
                    }
                }
            } catch {
                Log.w("\(error)")
                analyticsProvider.logWalletImportError(
                    mnemonic: mnemonic,
                    from: analyticsContext.from,
                    error: error
                )
                await MainActor.run {
                    completion()
                    onStayOnScreen?()
                }
            }
        }
    }

    func resolveWallets(mnemonic: CoreMnemonic) {
        guard network == .mainnet else {
            return
        }

        let walletStoreState = walletsUpdateAssembly.storesAssembly.walletsStore.getState()

        // skip for onboarding flow
        if case .empty = walletStoreState {
            return
        }

        guard let keyPair = try? mnemonic.toKeyPair() else {
            return
        }

        let walletsResolveService = walletsUpdateAssembly.servicesAssembly.walletsResolveService()
        walletsResolveService.resolveWallets(by: keyPair.publicKey)
    }

    @discardableResult
    func handleActiveWallets(
        request: WalletImportRequest,
        activeWalletModels: [ActiveWalletModel]
    ) -> Bool {
        let mnemonic = request.mnemonic
        let shouldAcceptWallet: (ActiveWalletModel) -> Bool = { wallet in
            switch mnemonic.type {
            case .bip39soft, .unknown:
                return wallet.history != .empty
            case .bip39, .ton:
                return true
            }
        }
        let activeWalletModels = activeWalletModels.filter(shouldAcceptWallet)
        guard !activeWalletModels.isEmpty else {
            analyticsProvider.logWalletImportError(
                mnemonic: mnemonic,
                from: analyticsContext.from,
                errorMessage: TKLocales.ImportWallet.incorrectPhrase
            )
            ToastPresenter.showToast(
                configuration: .defaultConfiguration(text: TKLocales.ImportWallet.incorrectPhrase)
            )
            return false
        }

        switch WalletVersionImportResolver.resolve(mnemonic: mnemonic, activeWallets: activeWalletModels) {
        case let .importRevision(revision):
            handleDidChooseRevisions(request: request, revisions: [revision])
        case let .showVersionSelection(v4r2, w5):
            openChooseWalletVersion(request: request, wallets: [w5, v4r2])
        case let .useExistingWalletSelection(wallets):
            handleExistingWalletSelection(request: request, activeWalletModels: wallets)
        }
        return true
    }

    var isWalletKindSelectionEnabled: Bool {
        network == .mainnet
    }

    func resolveDerivationType(phrase: [String]) -> DerivationType {
        if isWalletKindSelectionEnabled, DerivationType.isAmbiguous(phrase) {
            return .bip39
        }
        return .guessByWords(phrase)
    }

    func isWalletAlreadyImported(phrase: [String]) -> Bool {
        guard let publicKey = try? CoreMnemonic(
            mnemonicWords: phrase,
            type: resolveDerivationType(phrase: phrase)
        ).toKeyPair().publicKey else {
            return false
        }
        let wallets = walletsUpdateAssembly.storesAssembly.walletsStore.getState().wallets
        return wallets.contains { $0.network == network && (try? $0.publicKey)?.data == publicKey.data }
    }

    func startAutomaticImport(
        phrase: [String],
        derivationType: DerivationType,
        completion: @escaping () -> Void
    ) {
        let request = WalletImportRequest(
            mnemonic: CoreMnemonic(
                mnemonicWords: phrase,
                type: derivationType
            ),
            walletKindPreference: .automatic
        )
        detectActiveWallets(request: request, completion: completion)
        resolveWallets(mnemonic: request.mnemonic)
    }

    func loadWalletKindPreviewsIfNeeded(
        phrase: [String],
        completion: @escaping () -> Void
    ) {
        Task { @MainActor in
            let currency = storesAssembly.currencyStore.getState()
            let previewLoader = walletsUpdateAssembly.importWalletKindPreviewLoader(
                multichainAssembly: multichainAssembly
            )
            guard let previews = await previewLoader.loadPreviewsIfNeeded(
                words: phrase,
                network: network,
                currency: currency
            ) else {
                startAutomaticImport(
                    phrase: phrase,
                    derivationType: resolveDerivationType(phrase: phrase),
                    completion: completion
                )
                return
            }
            completion()
            openChooseWalletKind(
                phrase: phrase,
                tonPreview: previews.ton,
                multichainPreview: previews.multichain,
                currency: currency
            )
        }
    }

    func openChooseWalletKind(
        phrase: [String],
        tonPreview: ImportWalletKindPreview,
        multichainPreview: ImportWalletKindPreview,
        currency: Currency
    ) {
        let module = ChooseWalletKindAssembly.module(
            tonPreview: tonPreview,
            multichainPreview: multichainPreview,
            amountFormatter: walletsUpdateAssembly.formattersAssembly.amountFormatter,
            currency: currency
        )

        let moduleInput = module.input

        module.output.didSelectKind = { [weak self, weak moduleInput] kind in
            guard let self else { return }
            let derivationType: DerivationType = kind == .ton && DerivationType.isAmbiguous(phrase)
                ? .ton
                : .bip39
            let request = WalletImportRequest(
                mnemonic: CoreMnemonic(mnemonicWords: phrase, type: derivationType),
                walletKindPreference: .selected(kind)
            )
            self.detectActiveWallets(
                request: request,
                completion: {},
                onStayOnScreen: { moduleInput?.resetContinueImport() },
                onForwardNavigation: { moduleInput?.clearContinueLoader() }
            )
            self.resolveWallets(mnemonic: request.mnemonic)
        }

        module.view.setupBackButton()

        router.push(
            viewController: module.view,
            animated: true,
            onPopClosures: {},
            completion: nil
        )
    }

    func handleExistingWalletSelection(
        request: WalletImportRequest,
        activeWalletModels: [ActiveWalletModel]
    ) {
        if activeWalletModels.count == 1, activeWalletModels[0].revision == WalletContractVersion.currentVersion {
            handleDidChooseRevisions(request: request, revisions: [WalletContractVersion.currentVersion])
        } else {
            openChooseWalletToAdd(request: request, activeWalletModels: activeWalletModels)
        }
    }

    func openChooseWalletVersion(request: WalletImportRequest, wallets: [ActiveWalletModel]) {
        Task { @MainActor [self] in
            let currency = storesAssembly.currencyStore.getState()
            let rates = try? await walletsUpdateAssembly.servicesAssembly.ratesService().loadRates(
                jettons: [],
                currencies: [currency]
            )
            let tonRate = rates?.ton.first(where: { $0.currency == currency })

            let module = ChooseWalletVersionAssembly.module(
                wallets: wallets,
                amountFormatter: walletsUpdateAssembly.formattersAssembly.amountFormatter,
                network: network,
                tonRate: tonRate,
                currency: currency
            )

            let moduleInput = module.input

            module.output.didSelectWallet = { [weak self, weak moduleInput] wallet in
                self?.handleDidChooseRevisions(
                    request: request,
                    revisions: [wallet.revision],
                    onStayOnScreen: { moduleInput?.resetContinueImport() }
                )
                moduleInput?.clearContinueLoader()
            }

            module.view.setupBackButton()

            router.push(
                viewController: module.view,
                animated: true,
                onPopClosures: {},
                completion: nil
            )
        }
    }

    func openChooseWalletToAdd(
        request: WalletImportRequest,
        activeWalletModels: [ActiveWalletModel]
    ) {
        let module = ChooseWalletToAddAssembly.module(
            activeWalletModels: activeWalletModels,
            configuration: ChooseWalletToAddConfiguration(
                showRevision: true,
                selectLastRevision: true
            ),
            amountFormatter: walletsUpdateAssembly.formattersAssembly.amountFormatter,
            network: network
        )

        module.output.didSelectWallets = { [weak self] wallets in
            let revisions = wallets.map { $0.revision }
            self?.handleDidChooseRevisions(request: request, revisions: revisions)
        }

        module.view.setupBackButton()

        router.push(
            viewController: module.view,
            animated: true,
            onPopClosures: {},
            completion: nil
        )
    }

    func handleDidChooseRevisions(
        request: WalletImportRequest,
        revisions: [WalletContractVersion],
        onStayOnScreen: (() -> Void)? = nil
    ) {
        if hasPasscodeChecker.hasPasscode {
            openConfirmPasscode(
                request: request,
                revisions: revisions,
                onStayOnScreen: onStayOnScreen
            )
        } else {
            openCreatePasscode(
                request: request,
                revisions: revisions,
                onStayOnScreen: onStayOnScreen
            )
        }
    }

    func openCreatePasscode(
        request: WalletImportRequest,
        revisions: [WalletContractVersion],
        onStayOnScreen: (() -> Void)? = nil
    ) {
        let coordinator = PasscodeCreateCoordinator(
            router: router,
            biometryEnabler: makePasscodeBiometryEnabler()
        )

        coordinator.didCancel = { [weak self, weak coordinator] in
            self?.removeChild(coordinator)
            self?.router.dismiss(animated: true, completion: {
                onStayOnScreen?()
                self?.didCancel?()
            })
        }

        coordinator.didMismatch = { [weak self] in
            guard let self else { return }
            analyticsContext.logOnboarding(OnboardingPasscodeMismatch(), using: analyticsProvider)
        }

        coordinator.didCreatePasscode = { [weak self] passcode in
            guard let self else { return }
            analyticsContext.logOnboarding(OnboardingPasscodeCreated(), using: analyticsProvider)
            openNotifications(
                request: request,
                revisions: revisions,
                passcode: passcode,
                animated: true
            )
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openConfirmPasscode(
        request: WalletImportRequest,
        revisions: [WalletContractVersion],
        onStayOnScreen: (() -> Void)? = nil
    ) {
        PasscodeInputCoordinator.present(
            parentCoordinator: self,
            parentRouter: self.router,
            mnemonicAccess: walletsUpdateAssembly.secureAssembly.mnemonicAccess,
            securityStore: storesAssembly.securityStore,
            analyticsProvider: analyticsProvider,
            onCancel: {
                onStayOnScreen?()
            },
            onInput: { [weak self] passcode in
                self?.openNotifications(
                    request: request,
                    revisions: revisions,
                    passcode: passcode,
                    animated: true
                )
            }
        )
    }

    func openNotifications(
        request: WalletImportRequest,
        revisions: [WalletContractVersion],
        passcode: String,
        animated: Bool
    ) {
        OnboardingNotificationsStep.push(
            router: router,
            animated: animated
        ) { [weak self] in
            self?.openCustomizeWallet(
                request: request,
                revisions: revisions,
                passcode: passcode,
                animated: true
            )
        }
    }

    func openCustomizeWallet(
        request: WalletImportRequest,
        revisions: [WalletContractVersion],
        passcode: String,
        animated: Bool
    ) {
        let module = customizeWalletModule()

        module.output.didCustomizeWallet = { [weak self] model in
            guard let self else { return }
            Task {
                do {
                    try await self.importWallet(
                        request: request,
                        revisions: revisions,
                        model: model,
                        passcode: passcode
                    )
                    await MainActor.run {
                        self.didImportWallets?()
                    }
                } catch {
                    Log.e("Log: Wallet import failed", extraInfo: [
                        "error": error.localizedDescription,
                    ])
                    self.analyticsProvider.logWalletImportError(
                        mnemonic: request.mnemonic,
                        from: self.analyticsContext.from,
                        error: error
                    )
                }
            }
        }

        module.view.setupHeaderBackButton()
        router.push(viewController: module.view, animated: animated)
    }

    func importWallet(
        request: WalletImportRequest,
        revisions: [WalletContractVersion],
        model: CustomizeWalletModel,
        passcode: String
    ) async throws {
        let addController = walletsUpdateAssembly.walletAddController(
            multichainAssembly: multichainAssembly
        )
        let metaData = WalletMetaData(
            label: model.name,
            tintColor: model.tintColor,
            icon: model.icon
        )
        try await addController.importWallets(
            mnemonic: request.mnemonic,
            revisions: revisions,
            metaData: metaData,
            passcode: passcode,
            network: network,
            walletKindPreference: request.walletKindPreference
        )
        analyticsProvider.logWalletImportSuccess(
            mnemonic: request.mnemonic,
            from: analyticsContext.from
        )
    }

    func makePasscodeBiometryEnabler() -> PasscodeBiometryEnabler? {
        guard analyticsContext.from == .onboarding else { return nil }
        return PasscodeBiometryEnabler(
            mnemonicAccess: walletsUpdateAssembly.secureAssembly.mnemonicAccess,
            securityStore: storesAssembly.securityStore
        )
    }
}
