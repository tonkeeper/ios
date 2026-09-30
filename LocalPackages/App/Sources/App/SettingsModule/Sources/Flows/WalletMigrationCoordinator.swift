import KeeperCore
import TKCoordinator
import TKCore
import TKCryptoKit
import TKUIKit
import TonSwift
import TronSwift
import UIKit

final class WalletMigrationCoordinator: RouterCoordinator<NavigationControllerRouter> {
    enum Presentation {
        case modal
        case embedded
    }

    var didRequestOpenMerchantURL: ((URL, UIViewController) -> Void)?

    private let wallet: Wallet
    private let source: MigrationSource
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private let presentation: Presentation

    private var migrationRouter: NavigationControllerRouter?
    private var backupCoordinator: BackupCoordinator?
    private var feePickerCoordinator: NetworkFeePickerCoordinator?
    private weak var confirmationViewModel: WalletMigrationConfirmationViewModel?
    private var pendingSourceWalletId: String?
    private var dismissMigration: (() -> Void)?
    private let depositPendingTracker: DepositPendingTracker

    /// Held strongly, and released here rather than only from the dismissal callbacks: the loader
    /// itself is cached weakly, and a flow that dies without handing the budget back would leave
    /// background reloading off for the rest of the session.
    private let balanceLoader: BalanceLoader
    /// Per instance, not a stable name: settings and a deeplink can each open a migration, and a
    /// shared id makes them one owner — the first to finish would hand back silence the other is
    /// still broadcasting under.
    private let quietOwner = BalanceQuietOwner.flow(id: UUID().uuidString)

    init(
        wallet: Wallet,
        source: MigrationSource,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter,
        depositPendingTracker: DepositPendingTracker,
        presentation: Presentation = .modal
    ) {
        self.wallet = wallet
        self.source = source
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        self.presentation = presentation
        self.depositPendingTracker = depositPendingTracker
        balanceLoader = keeperCoreMainAssembly.loadersAssembly.balanceLoader
        super.init(router: router)
    }

    deinit {
        balanceLoader.setQuiet(false, owner: quietOwner)
    }

    override func start() {
        coreAssembly.analyticsProvider.log(MigrationStart(from: source))
        balanceLoader.setQuiet(true, owner: quietOwner)
        openMigration()
    }
}

private extension WalletMigrationCoordinator {
    func openMigration() {
        let viewModel = WalletMigrationViewModel(
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            walletMigrationService: keeperCoreMainAssembly.servicesAssembly.walletMigrationService(),
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            analyticsProvider: coreAssembly.analyticsProvider
        )

        let viewController = WalletMigrationHostingViewController(viewModel: viewModel)

        switch presentation {
        case .modal:
            openMigrationModally(viewModel: viewModel, viewController: viewController)
        case .embedded:
            openMigrationEmbedded(viewModel: viewModel, viewController: viewController)
        }
    }

    func openMigrationModally(
        viewModel: WalletMigrationViewModel,
        viewController: WalletMigrationHostingViewController
    ) {
        let navigationController = TKNavigationController(rootViewController: viewController)
        navigationController.configureTransparentAppearance()
        migrationRouter = NavigationControllerRouter(rootViewController: navigationController)

        let dismiss: () -> Void = { [weak self, weak navigationController] in
            guard let navigationController else { return }
            navigationController.dismiss(animated: true) {
                self?.resumeBackgroundBalanceReload()
                self?.didFinish?(self)
            }
        }

        dismissMigration = dismiss

        viewModel.didRequestClose = dismiss
        viewModel.didTapContinue = { [weak self] sourceWalletId in
            self?.handleContinue(sourceWalletId: sourceWalletId)
        }
        viewModel.didTapAddTonWallet = { [weak self] in
            self?.openAddTonWallet()
        }
        viewModel.didTapHowItWorks = { [weak self] in
            self?.openMigrationInfo()
        }

        viewController.setupRightCloseButton(dismiss)

        router.present(
            navigationController,
            onDismiss: { [weak self] in
                self?.resumeBackgroundBalanceReload()
                self?.didFinish?(self)
            }
        )
    }

    func openMigrationEmbedded(
        viewModel: WalletMigrationViewModel,
        viewController: WalletMigrationHostingViewController
    ) {
        migrationRouter = router

        let finish: () -> Void = { [weak self] in
            self?.resumeBackgroundBalanceReload()
            self?.didFinish?(self)
        }

        dismissMigration = finish

        viewModel.didTapContinue = { [weak self] sourceWalletId in
            self?.handleContinue(sourceWalletId: sourceWalletId)
        }
        viewModel.didTapHowItWorks = { [weak self] in
            self?.openMigrationInfo()
        }
        viewModel.didDetectNoMigratableWallets = finish

        viewController.showsNavigationBar = true
        viewController.isInteractivePopDisabled = true
        viewController.setupSkipButton(finish)
        router.push(viewController: viewController, animated: true)
    }

    func resumeBackgroundBalanceReload() {
        balanceLoader.setQuiet(false, owner: quietOwner)
    }

    func openMigrationInfo() {
        guard let migrationRouter else { return }

        PopupContentPresenter.present(
            from: migrationRouter.rootViewController
        ) { dismisser in
            WalletMigrationInfoPopupView(dismiss: { dismisser.dismiss() })
        }
    }

    func openAddTonWallet() {
        guard let migrationRouter else { return }

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
        ).createAddWalletCoordinator(
            options: [.importRegular],
            router: ViewControllerRouter(rootViewController: migrationRouter.rootViewController),
            analyticsContext: WalletFlowAnalyticsContext(from: .main)
        )

        coordinator.didAddWallets = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        coordinator.didCancel = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func handleContinue(sourceWalletId: String) {
        pendingSourceWalletId = sourceWalletId

        let destinationWallet = keeperCoreMainAssembly.storesAssembly.walletsStore
            .getWallet(id: wallet.id) ?? wallet
        if requiresBackup(for: destinationWallet) {
            openRequiredBackup(wallet: destinationWallet)
            return
        }

        proceedWithMigration(sourceWalletId: sourceWalletId)
    }

    func requiresBackup(for wallet: Wallet) -> Bool {
        wallet.isBackupAvailable && !wallet.hasBackup
    }

    func openRequiredBackup(wallet: Wallet) {
        guard let migrationRouter else { return }

        let coordinator = BackupModule(
            dependencies: BackupModule.Dependencies(
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                coreAssembly: coreAssembly
            )
        ).createBackupCoordinator(
            router: migrationRouter,
            wallet: wallet,
            source: .walletSetupSection,
            startsWithIntro: true
        )

        coordinator.didCompleteBackup = { [weak self, weak coordinator] in
            guard let self, let sourceWalletId = self.pendingSourceWalletId else { return }
            self.proceedWithMigration(sourceWalletId: sourceWalletId)
            if let coordinator {
                self.removeChild(coordinator)
            }
            self.backupCoordinator = nil
        }

        backupCoordinator = coordinator
        addChild(coordinator)
        coordinator.start()
    }

    func proceedWithMigration(sourceWalletId: String) {
        guard let migrationRouter,
              let sourceWallet = keeperCoreMainAssembly.storesAssembly.walletsStore.getWallet(id: sourceWalletId)
        else {
            return
        }

        let viewModel = WalletMigrationConfirmationViewModel(
            sourceWallet: sourceWallet,
            destinationWallet: wallet,
            walletMigrationService: keeperCoreMainAssembly.servicesAssembly.walletMigrationService(),
            nftService: keeperCoreMainAssembly.servicesAssembly.nftService(),
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            walletNFTsRepository: keeperCoreMainAssembly.repositoriesAssembly.walletNFTRepository(),
            ratesService: keeperCoreMainAssembly.servicesAssembly.ratesService(),
            tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
            analyticsProvider: coreAssembly.analyticsProvider,
            onBack: { [weak self] in
                self?.migrationRouter?.pop()
            },
            onClose: { [weak self] in
                self?.dismissMigration?()
            },
            onDepositTon: { [weak self] onClose in
                self?.openBuyTon(for: sourceWallet, onClose: onClose)
            },
            onDepositTrx: { [weak self] onClose in
                self?.openBuyTrx(for: sourceWallet, onClose: onClose)
            },
            onDepositWallet: { [weak self] onClose in
                self?.openDeposit(
                    preselected: .ton(.ton),
                    for: sourceWallet,
                    onClose: onClose
                )
            },
            onRefillBattery: { [weak self] onRechargeSuccess in
                self?.openBatteryRefill(
                    wallet: sourceWallet,
                    onRechargeSuccess: onRechargeSuccess
                )
            },
            onPresentInsufficientFee: { [weak self] content in
                self?.presentInsufficientFee(content: content)
            },
            onConfirm: { [weak self] payload in
                guard let self else { return }
                try await self.executeMigration(
                    sourceWallet: sourceWallet,
                    payload: payload
                )
            },
            onOpenFeePicker: { [weak self] presentation in
                guard let self, let migrationRouter = self.migrationRouter else { return }
                let coordinator = NetworkFeePickerCoordinator(router: migrationRouter)
                self.feePickerCoordinator = coordinator
                coordinator.start(presentation: presentation)
            },
            onShowMigrationInfo: { [weak self] in
                self?.openMigrationInfo()
            },
            onSuccess: { [weak self] in
                guard let self else { return }
                self.resumeBackgroundBalanceReload()
                NotificationCenter.default.postTransactionSendNotification(wallet: self.wallet)
                Task { [balanceLoader = self.balanceLoader, wallet = self.wallet] in
                    async let source: BalanceRefreshResult = balanceLoader.reloadBalance(wallet: sourceWallet, priority: .userInitiated)
                    async let target: BalanceRefreshResult = balanceLoader.reloadBalance(wallet: wallet, priority: .userInitiated)
                    _ = await(source, target)
                }
                self.dismissMigration?()
            }
        )

        confirmationViewModel = viewModel
        let viewController = WalletMigrationConfirmationHostingViewController(viewModel: viewModel)
        migrationRouter.push(viewController: viewController)
    }

    func presentInsufficientFee(content: InsufficientFeePopupContent) {
        guard let migrationRouter,
              let viewModel = confirmationViewModel
        else {
            return
        }

        var didHandleAction = false
        let deposit = {
            didHandleAction = true
            viewModel.depositForInsufficientFee()
        }
        let continueMigration = {
            didHandleAction = true
            viewModel.continueWithAvailableChain()
        }
        let isDepositPrimary = content.primaryAction == .deposit
        let sheet = PopupContentPresenter.presentInsufficientFee(
            content: content,
            from: migrationRouter.rootViewController,
            onPrimary: isDepositPrimary ? deposit : continueMigration,
            onSecondary: content.secondaryButtonTitle == nil
                ? nil
                : (isDepositPrimary ? continueMigration : deposit)
        )
        sheet.didClose = { [weak self] _ in
            guard !didHandleAction else { return }
            self?.migrationRouter?.pop()
        }
    }

    func executeMigration(
        sourceWallet: Wallet,
        payload: WalletMigrationConfirmationViewModel.ConfirmPayload
    ) async throws {
        switch sourceWallet.kind {
        case .regular:
            try await executeRegularMigration(
                sourceWallet: sourceWallet,
                payload: payload
            )
        case .ledger, .signer, .keystone, .lockup, .watchonly:
            throw WalletMigrationExecutionError.unsupportedWalletKind
        }
    }

    func executeRegularMigration(
        sourceWallet: Wallet,
        payload: WalletMigrationConfirmationViewModel.ConfirmPayload
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let migrationRouter else {
                continuation.resume(throwing: CancellationError())
                return
            }

            PasscodeInputCoordinator.present(
                parentCoordinator: self,
                parentRouter: migrationRouter,
                mnemonicAccess: keeperCoreMainAssembly.mnemonicAccess,
                securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
                onCancel: {
                    continuation.resume(throwing: CancellationError())
                },
                onInput: { [weak self] passcode in
                    guard let self else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    Task {
                        var hasSettledPart = false
                        do {
                            let mnemonic = try await self.keeperCoreMainAssembly.mnemonicAccess.getMnemonic(
                                wallet: sourceWallet,
                                passcode: passcode
                            )

                            let keyPair = try mnemonic.toKeyPair()
                            let tonSigner = WalletTransferSecretKeySigner(secretKey: keyPair.privateKey.data)

                            if payload.sendTron, let tronResult = payload.tron {
                                let feeMethod = payload.tronFeeMethod ?? tronResult.preferredFeeMethod
                                guard let feeMethod else {
                                    throw WalletMigrationExecutionError.insufficientTronFee
                                }
                                let tronSignHandler: (TronSwift.TxID, Wallet) async throws(TronTransferSignError) -> TronSwift.SignedTxID = { txID, _ throws(TronTransferSignError) in
                                    do {
                                        let privateKey = try TonTron.derivedKeyPair(
                                            tonMnemonic: mnemonic.mnemonicWords,
                                            index: 0
                                        ).privateKey
                                        return try Signer().sign(hash: txID, privateKey: privateKey)
                                    } catch {
                                        throw .failedToSign(message: error.localizedDescription)
                                    }
                                }
                                let executionService = self.keeperCoreMainAssembly.servicesAssembly
                                    .walletMigrationExecutionService()

                                let sendsUSDT = tronResult.hasUSDT
                                let plannedTRX = tronResult.trxTransferAmount(for: feeMethod) > 0
                                let tryTrxSweep = tronResult.shouldAttemptTrxSweep(feeMethod: feeMethod)

                                // USDT first, then TRX. Reversing that lets a full TRX sweep drain
                                // free bandwidth before the USDT TRC-20 leg (esp. Battery-relayed).
                                try await withMigrationPart(.tronUsdt, isPartial: hasSettledPart) {
                                    try await executionService.executeTronUSDTMigration(
                                        sourceWallet: sourceWallet,
                                        prepareResult: tronResult,
                                        feeMethod: feeMethod,
                                        tronSignHandler: tronSignHandler
                                    )
                                }
                                hasSettledPart = hasSettledPart || sendsUSDT

                                if tryTrxSweep {
                                    try await withMigrationPart(.tronTrx, isPartial: hasSettledPart) {
                                        try await executionService.executeTronTRXMigration(
                                            sourceWallet: sourceWallet,
                                            prepareResult: tronResult,
                                            feeMethod: feeMethod,
                                            tronSignHandler: tronSignHandler,
                                            allowSkipInsufficient: sendsUSDT && !plannedTRX
                                        )
                                    }
                                    hasSettledPart = hasSettledPart || plannedTRX
                                }
                            }

                            if payload.sendTon, let tonResult = payload.ton {
                                let tonFeeMethod = payload.tonFeeMethod
                                    ?? tonResult.preferredFeeMethod
                                    ?? .ton(amountNano: tonResult.totalFees)
                                try await withMigrationPart(.ton, isPartial: hasSettledPart) {
                                    try await self.keeperCoreMainAssembly.servicesAssembly
                                        .walletMigrationExecutionService()
                                        .executeMigration(
                                            sourceWallet: sourceWallet,
                                            prepareResult: tonResult,
                                            feeMethod: tonFeeMethod,
                                            signer: tonSigner,
                                            batterySendProof: { boc in
                                                self.keeperCoreMainAssembly.multichainAssembly
                                                    .chainKitService
                                                    .batterySendProof(
                                                        wallet: sourceWallet,
                                                        mnemonic: mnemonic.mnemonicWords
                                                            .joined(separator: " "),
                                                        boc: boc
                                                    )
                                            }
                                        )
                                }
                            }

                            self.markRaffleMigrationCompleted()

                            await MainActor.run {
                                continuation.resume()
                            }
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            )
        }
    }

    func markRaffleMigrationCompleted() {
        guard case let .multichain(state) = wallet.multichain else { return }
        let service = keeperCoreMainAssembly.servicesAssembly.multichainService()
        let walletId = state.walletId
        Task { try? await service.completeRaffleMigration(walletId: walletId) }
    }

    func openBatteryRefill(
        wallet: Wallet,
        onRechargeSuccess: @escaping () -> Void
    ) {
        guard let migrationRouter else { return }

        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = BatteryRefillCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            wallet: wallet,
            jettonMasterAddress: nil,
            initiatedBy: .user,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        coordinator.didRechargeSuccess = { [weak self, weak navigationController, weak coordinator] in
            navigationController?.dismiss(animated: true) {
                self?.removeChild(coordinator)
                onRechargeSuccess()
            }
        }
        coordinator.didFinish = { [weak self, weak navigationController] coordinator in
            navigationController?.dismiss(animated: true)
            self?.removeChild(coordinator)
        }

        addChild(coordinator)
        coordinator.start(deeplink: nil)
        migrationRouter.presentOverTopPresented(
            navigationController,
            completion: {
                coordinator.didAppear()
            },
            onDismiss: { [weak self, weak coordinator] in
                self?.removeChild(coordinator)
            }
        )
    }

    func openBuyTon(for wallet: Wallet, onClose: @escaping () -> Void) {
        openFiatPurchase(
            for: wallet,
            symbol: TonInfo.symbol,
            network: "NATIVE",
            receivePreselected: .ton(.ton),
            onClose: onClose
        )
    }

    /// TRX exists on a single network, so the symbol alone identifies the on-ramp asset
    /// and no network hint is needed to preselect it.
    func openBuyTrx(for wallet: Wallet, onClose: @escaping () -> Void) {
        openFiatPurchase(
            for: wallet,
            symbol: TRX.symbol,
            network: nil,
            receivePreselected: .tron(.trx),
            onClose: onClose
        )
    }

    func openFiatPurchase(
        for wallet: Wallet,
        symbol: String,
        network: String?,
        receivePreselected: Token,
        onClose: @escaping () -> Void
    ) {
        guard let migrationRouter else { return }

        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)
        let rampRouter = NavigationControllerRouter(rootViewController: navigationController)

        let coordinator = RampCoordinator(
            flow: .deposit,
            router: rampRouter,
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            initialDeeplink: RampDeeplinkParameters(
                fromToken: symbol,
                toToken: nil,
                toNetwork: nil,
                fromNetwork: network,
                cashMethod: nil,
                itemType: .fiat
            ),
            entrySource: .walletScreen,
            depositPendingTracker: depositPendingTracker
        )

        // Reload only once back on the confirmation screen: a mid-flow reload would
        // re-present the insufficient-fee popup from a controller that is still presenting.
        let onReturnToConfirm = { [weak self] in
            guard let self,
                  let migrationRouter = self.migrationRouter,
                  migrationRouter.rootViewController.presentedViewController == nil
            else { return }
            onClose()
        }

        coordinator.didTapReceive = { [weak self] receiveWallet in
            self?.openDeposit(
                preselected: receivePreselected,
                for: receiveWallet,
                onClose: onReturnToConfirm
            )
        }

        coordinator.didTapOpenMerchant = { [weak self, weak navigationController] url in
            guard let self, let navigationController else { return }
            self.didRequestOpenMerchantURL?(url, navigationController)
        }

        coordinator.didClose = { [weak self, weak navigationController, weak coordinator] in
            navigationController?.dismiss(animated: true) {
                self?.removeChild(coordinator)
                onReturnToConfirm()
            }
        }

        addChild(coordinator)
        coordinator.start()

        migrationRouter.presentOverTopPresented(
            navigationController,
            onDismiss: { [weak self, weak coordinator] in
                self?.removeChild(coordinator)
                onReturnToConfirm()
            }
        )
    }

    /// The migration source is always a legacy TON wallet, so its deposit receive routes to the
    /// legacy screen with an inline TON/TRC20 switcher. Offer both networks (TRC20 only when the
    /// wallet has a TRON account) and preselect the one the user came to top up, matching Android.
    func migrationReceiveTokens(for wallet: Wallet) -> [Token] {
        var tokens: [Token] = [.ton(.ton)]
        if wallet.tron != nil {
            tokens.append(.tron(.trx))
        }
        return tokens
    }

    func openDeposit(
        preselected: Token,
        for wallet: Wallet,
        onClose: @escaping () -> Void
    ) {
        guard let migrationRouter else { return }

        let coordinator = ReceiveModule(
            dependencies: .init(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        )
        .createReceiveCoordinator(
            router: migrationRouter,
            tokens: migrationReceiveTokens(for: wallet),
            wallet: wallet,
            preselected: preselected
        )

        coordinator.didClose = { [weak self, weak coordinator] in
            self?.removeChild(coordinator)
            onClose()
        }

        addChild(coordinator)
        coordinator.start()
    }
}
