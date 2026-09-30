import BigInt
import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKScreenKit
import TKUIKit
import TronSwift
import UIKit

private struct MultichainSendAnalyticsContext {
    let source: SendAnalyticsSource
    let asset: String
    let amount: Double
}

final class MultichainSendCoordinator: RouterCoordinator<NavigationControllerRouter>, SendCoordinator {
    var didSendSuccessfully: ((RouterCoordinator<NavigationControllerRouter>?) -> Void)?
    var didRequestOpenBuySell: ((_ isInternalPurchasing: Bool) -> Void)?
    var didRequestRefill: ((Token, _ onRefill: @escaping () -> Void) -> Void)?
    var didRequestOpenBattery: ((@escaping () -> Void) -> Void)?
    var didRequestFeeDeposit: ((_ assetId: String, _ onDismiss: @escaping () -> Void) -> Void)?

    private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?
    private lazy var feePickerCoordinator = NetworkFeePickerCoordinator(
        router: router
    )

    private let wallet: Wallet
    private let multichainState: MultichainWalletState
    private let sendSource: SendAnalyticsSource
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let transactionSentNotificationPatch: @Sendable (inout [String: Any]) -> Void
    private let recipient: MultichainRecipient?
    private let comment: String?
    private let analyticsProvider: AnalyticsProvider
    private let entry: MultichainSendEntry
    private let nativeFeeShortagePopupPresenter: MultichainNativeFeeShortagePopupPresenter

    private var selectedAsset: MultichainAsset?
    private var allowsAutomaticChainSwitch: Bool

    init(
        router: NavigationControllerRouter,
        wallet: Wallet,
        multichainState: MultichainWalletState,
        entry: MultichainSendEntry,
        sendSource: SendAnalyticsSource,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        transactionSentNotificationPatch: @Sendable @escaping (inout [String: Any]) -> Void = { _ in },
        recipient: MultichainRecipient? = nil,
        comment: String? = nil
    ) {
        self.wallet = wallet
        self.multichainState = multichainState
        self.sendSource = sendSource
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.transactionSentNotificationPatch = transactionSentNotificationPatch
        self.recipient = recipient
        self.comment = comment
        self.entry = entry
        self.analyticsProvider = coreAssembly.analyticsProvider
        nativeFeeShortagePopupPresenter = MultichainNativeFeeShortagePopupPresenter(
            wallet: wallet,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )
        switch entry {
        case let .enterAmount(sendInput):
            selectedAsset = sendInput.item.asset
        case .tokenPicker:
            selectedAsset = nil
        }
        switch sendSource {
        case .qrCode:
            allowsAutomaticChainSwitch = true
        case .jettonScreen:
            allowsAutomaticChainSwitch = false
        default:
            allowsAutomaticChainSwitch = recipient == nil
        }
        super.init(router: router)
    }

    override func start() {
        start(pushAnimated: false)
    }

    func start(pushAnimated: Bool) {
        logSendOpen()
        switch entry {
        case let .enterAmount(sendInput):
            if sendInput.isReadyForConfirmation(recipient: recipient, wallet: wallet),
               let sendData = SendData.multichainSendData(
                   wallet: wallet,
                   recipient: recipient,
                   item: sendInput.item,
                   comment: comment,
                   isMaxAmount: false
               )
            {
                let context = makeSendAnalyticsContext(sendData: sendData)
                openSendConfirmation(sendData: sendData, analyticsContext: context)
            } else {
                openSend(sendInput: sendInput, pushAnimated: pushAnimated)
            }
        case let .tokenPicker(allowedChains, initialChain):
            openInitialTokenPicker(
                pushAnimated: pushAnimated,
                allowedChains: allowedChains,
                initialChain: initialChain
            )
        }
    }

    func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
        guard let walletTransferSignCoordinator else { return false }
        walletTransferSignCoordinator.externalSignHandler?(sign)
        walletTransferSignCoordinator.externalSignHandler = nil
        return true
    }

    override func didMoveTo(toParent parent: (any Coordinator)?) {
        if parent == nil {
            walletTransferSignCoordinator?.externalSignHandler?(nil)
        }
    }
}

private extension MultichainSendCoordinator {
    func openSend(sendInput: MultichainSendInput, pushAnimated: Bool) {
        selectedAsset = sendInput.item.asset

        let module = MultichainSendV3Assembly.module(
            wallet: wallet,
            sendInput: sendInput,
            recipient: recipient,
            comment: comment,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            autofocus: recipient != nil ? .amount : .recipient
        )

        module.output.didContinueSend = { [weak self] sendData in
            guard let self else { return }
            self.logSendClick(sendData: sendData)
            let context = self.makeSendAnalyticsContext(sendData: sendData)
            self.openSendConfirmation(sendData: sendData, analyticsContext: context)
        }

        module.output.didTapPicker = { [weak self] _, asset in
            guard let self else { return }
            self.openTokenPicker(
                asset: asset,
                sourceViewController: self.router.rootViewController,
                completion: { asset in
                    self.allowsAutomaticChainSwitch = false
                    self.selectedAsset = asset
                    module.input.updateWithAsset(asset)
                }
            )
        }

        module.output.didTapScan = { [weak self] in
            self?.openScan(completion: { deeplink in
                self?.handleScan(deeplink: deeplink, input: module.input)
            })
        }

        module.output.didTapClose = { [weak self] in
            self?.didFinish?(self)
        }

        router.push(viewController: module.view, animated: pushAnimated)
    }

    func openInitialTokenPicker(
        pushAnimated: Bool,
        allowedChains: Set<MultichainChain>?,
        initialChain: MultichainChain?
    ) {
        let module = assetPickerModule(
            selectedAsset: nil,
            presentation: .pushed,
            allowedChains: allowedChains,
            initialChain: initialChain
        )

        module.output.didSelectAsset = { [weak self] asset in
            guard let self else { return }
            self.allowsAutomaticChainSwitch = false
            self.openSend(
                sendInput: MultichainSendInput(item: MultichainSendItem(asset: asset, amount: 0)),
                pushAnimated: true
            )
        }

        module.output.didFinish = { [weak self] in
            guard let self else { return }
            self.didFinish?(self)
        }

        router.push(viewController: module.view, animated: pushAnimated)
    }

    func openTokenPicker(
        asset: MultichainAsset,
        sourceViewController: UIViewController,
        completion: @escaping (MultichainAsset) -> Void
    ) {
        let module = assetPickerModule(selectedAsset: asset, presentation: .modal)

        module.output.didSelectAsset = { asset in
            completion(asset)
        }

        module.output.didFinish = { [weak viewController = module.view] in
            viewController?.dismiss(animated: true)
        }

        sourceViewController.topPresentedViewController().present(
            module.view,
            animated: true
        )
    }

    func assetPickerModule(
        selectedAsset: MultichainAsset?,
        presentation: TokenPickerV2Presentation,
        allowedChains: Set<MultichainChain>? = nil,
        initialChain: MultichainChain? = nil
    ) -> MVVMModule<TokenPickerV2HostingViewController, TokenPickerV2ModuleOutput, Void> {
        let model = SendTokenV2PickerModel(
            multichainState: multichainState,
            displayMode: .includingSelection(selectedAsset),
            searchBehavior: .account,
            multichainService: keeperCoreMainAssembly.servicesAssembly.multichainService(),
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            isTransferSupported: keeperCoreMainAssembly.multichainAssembly.chainKitService.isTransferSupported(asset:),
            allowedChains: allowedChains,
            initialChain: initialChain
        )

        return TokenPickerV2Assembly.module(
            title: TKLocales.Multichain.AssetPicker.chooseTitle,
            wallet: wallet,
            model: model,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            presentation: presentation
        )
    }

    func openScan(completion: @escaping (KeeperCore.Deeplink) -> Void) {
        let scannerAssembly = keeperCoreMainAssembly.scannerAssembly()
        let scanModule = ScannerModule(
            dependencies: ScannerModule.Dependencies(
                coreAssembly: coreAssembly,
                scannerAssembly: scannerAssembly
            )
        ).createScannerModule(
            configurator: DefaultScannerControllerConfigurator(
                extensions: [],
                deeplinkParser: scannerAssembly.deeplinkParser,
                isMultichainEnabled: wallet.isMultichain
            ),
            uiConfiguration: ScannerUIConfiguration(
                title: TKLocales.Scanner.title,
                subtitle: nil,
                isFlashlightVisible: true
            )
        )

        let navigationController = TKNavigationController(rootViewController: scanModule.view)
        navigationController.configureTransparentAppearance()

        scanModule.output.didScanDeeplink = { [weak self] deeplink in
            self?.router.dismiss(completion: {
                completion(deeplink)
            })
        }

        scanModule.output.didFailScan = { [weak self] error, shouldDismiss in
            ToastPresenter.hideAll()
            guard let error else { return }
            ToastPresenter.showToast(configuration: .init(title: error))
            if shouldDismiss {
                self?.router.dismiss()
            }
        }

        router.present(navigationController)
    }

    func handleScan(
        deeplink: KeeperCore.Deeplink,
        input: MultichainSendV3ModuleInput
    ) {
        guard let scanned = MultichainScannedTransfer(deeplink: deeplink) else {
            return
        }
        let selectedChain = selectedAsset?.asset.chain
        guard let recipient = MultichainSendRecipientResolver().resolveScan(
            candidates: scanned.candidates,
            selectedChain: selectedChain,
            walletChains: multichainState.addresses.map(\.chain),
            network: wallet.network
        ) else {
            ToastPresenter.showToast(
                configuration: ToastPresenter.Configuration(title: TKLocales.Send.invalidAddress)
            )
            return
        }

        switch MultichainScanApplication(
            scannedAssetId: scanned.assetId,
            selectedAssetId: selectedAsset?.asset.assetId,
            recipientChain: recipient.chain,
            selectedChain: selectedChain,
            allowsAutomaticChainSwitch: allowsAutomaticChainSwitch
        ) {
        case .applyInPlace:
            apply(scanned, recipient: recipient, input: input)
        case let .switchAsset(assetId):
            Task { @MainActor [weak self, input] in
                guard let self else { return }
                await self.switchToAssetAndApply(
                    scanned,
                    assetId: assetId,
                    recipient: recipient,
                    input: input
                )
            }
        }
    }

    func switchToAssetAndApply(
        _ scanned: MultichainScannedTransfer,
        assetId: String,
        recipient: MultichainRecipient,
        input: MultichainSendV3ModuleInput
    ) async {
        let assetResolver = MultichainSendAssetResolver(
            multichainAssetBalanceProvider: keeperCoreMainAssembly.multichainAssembly.multichainAssetBalanceProvider,
            assetDetailsService: keeperCoreMainAssembly.servicesAssembly.assetDetailsService()
        )
        guard let asset = await assetResolver.resolveAsset(
            for: assetId,
            multichainState: multichainState
        ),
            keeperCoreMainAssembly.multichainAssembly.chainKitService.isTransferSupported(asset: asset)
        else {
            showMultichainSendLoadError()
            return
        }

        selectedAsset = asset
        input.updateWithAsset(asset)
        apply(scanned, recipient: recipient, input: input)
    }

    func apply(
        _ scanned: MultichainScannedTransfer,
        recipient: MultichainRecipient,
        input: MultichainSendV3ModuleInput
    ) {
        input.setRecipient(recipient)
        if let amount = scanned.amount,
           scanned.assetId == nil || scanned.assetId == selectedAsset?.asset.assetId
        {
            input.setAmount(amount)
        }
        if let comment = scanned.comment {
            input.setComment(comment)
        }
    }

    func showMultichainSendLoadError() {
        ToastPresenter.showToast(
            configuration: ToastPresenter.Configuration(
                title: TKLocales.Trade.Assets.Errors.load
            )
        )
    }
}

private extension MultichainSendCoordinator {
    func openSendConfirmation(
        sendData: SendData,
        analyticsContext: MultichainSendAnalyticsContext?
    ) {
        guard case let .multichain(multichain) = sendData else {
            return
        }

        let transactionConfirmationController = keeperCoreMainAssembly.multichainTransferTransactionConfirmationController(
            wallet: multichain.wallet,
            recipient: multichain.recipient,
            asset: multichain.asset,
            amount: multichain.amount,
            comment: multichain.comment,
            isMaxAmount: multichain.isMaxAmount,
            passcodeProvider: { [weak self, keeperCoreMainAssembly] in
                guard let self else {
                    return nil
                }
                return await PasscodeInputCoordinator.getPasscode(
                    parentCoordinator: self,
                    parentRouter: router,
                    mnemonicAccess: keeperCoreMainAssembly.mnemonicAccess,
                    securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
                    analyticsProvider: analyticsProvider
                )
            }
        )
        let tronSignHandler = { [weak self, keeperCoreMainAssembly, coreAssembly] (txID: TronSwift.TxID, wallet: Wallet) async throws(TronTransferSignError) -> TronSwift.SignedTxID in
            guard let self else {
                throw .cancelled
            }
            let coordinator = TronUSDTTransferSignCoordinator(
                router: ViewControllerRouter(rootViewController: router.rootViewController),
                wallet: wallet,
                txID: txID,
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                coreAssembly: coreAssembly
            )
            return try await coordinator
                .handleSign(parentCoordinator: self)
                .get()
        }
        transactionConfirmationController.tronSignHandler = tronSignHandler

        let emulateMetadata = transferRedMetadata(context: analyticsContext)
        var emulateRedSession: RedAnalyticsSessionHolder?
        var sendRedSession: RedAnalyticsSessionHolder?

        let module = TransactionConfirmationAssembly.module(
            transactionConfirmationController: transactionConfirmationController,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            featureFlags: coreAssembly.featureFlags,
            transactionSentNotificationPatch: transactionSentNotificationPatch,
            withdrawDisplayInfo: nil
        )

        module.output.didOpenFeePicker = { [weak self] presentation in
            self?.feePickerCoordinator.start(presentation: presentation)
        }

        module.output.didRequireSign = { [weak self, keeperCoreMainAssembly, coreAssembly] walletTransfer, wallet throws(WalletTransferSignError) in
            guard let self else {
                throw .cancelled
            }
            let coordinator = WalletTransferSignCoordinator(
                router: ViewControllerRouter(rootViewController: router.rootViewController),
                wallet: wallet,
                transferData: walletTransfer,
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                coreAssembly: coreAssembly
            )

            self.walletTransferSignCoordinator = coordinator

            let result = await coordinator.handleSign(parentCoordinator: self)

            switch result {
            case let .success(data):
                return data
            case let .failure(error):
                throw error
            }
        }

        module.output.didStartEmulation = { [weak self] in
            guard let self else { return }
            self.nativeFeeShortagePopupPresenter.startNewFeeCalculation()
            let redSession = RedAnalyticsSessionHolder(
                analytics: self.analyticsProvider
            )
            redSession.start(
                flow: .transfer,
                operation: .emulate,
                attemptSource: analyticsContext?.source.redAttemptSource,
                otherMetadata: emulateMetadata
            )
            emulateRedSession = redSession
        }

        module.output.didFinishEmulation = { error in
            emulateRedSession?.finish(
                outcome: error == nil ? .success : .fail,
                error: error,
                stage: "emulate"
            )
            emulateRedSession = nil
        }

        module.output.didCancelEmulation = {
            emulateRedSession?.finish(
                outcome: .cancel,
                stage: "emulate"
            )
            emulateRedSession = nil
        }

        module.output.didStartConfirmTransaction = { [weak self] model in
            guard let self else { return }
            let feeAsset = self.feeAsset(model: model, context: analyticsContext)
            let metadata = self.transferRedMetadata(context: analyticsContext, feePaidIn: feeAsset.rawValue)
            let redSession = RedAnalyticsSessionHolder(
                analytics: self.analyticsProvider
            )
            redSession.start(
                flow: .transfer,
                operation: .send,
                attemptSource: analyticsContext?.source.redAttemptSource,
                otherMetadata: metadata
            )
            sendRedSession = redSession
            self.logSendConfirm(model: model, context: analyticsContext)
        }

        module.output.didCancelTransaction = {
            sendRedSession?.finish(
                outcome: .cancel,
                stage: "confirm"
            )
            sendRedSession = nil
        }

        module.output.didClose = { [weak self] in
            guard let self else { return }
            self.didFinish?(self)
        }

        module.output.didConfirmTransaction = { [weak self] model in
            guard let self else { return }
            sendRedSession?.finish(
                outcome: .success,
                stage: "send"
            )
            sendRedSession = nil
            self.logSendSuccess(model: model, context: analyticsContext)
            if let event = TransactionSent(
                wallet: self.wallet,
                model: model,
                origin: self.sendSource.transactionOrigin
            ) {
                self.analyticsProvider.log(event, utm: self.sendSource.utm)
            }
            self.didSendSuccessfully?(self)
        }

        module.output.didFailTransaction = { [weak self] model, error in
            guard let self else { return }
            sendRedSession?.finish(
                outcome: .fail,
                error: error,
                stage: "send"
            )
            sendRedSession = nil
            self.logSendFailed(model: model, error: error, context: analyticsContext)
        }

        module.output.didProduceInsufficientFundsError = { _ in
            ToastPresenter.showToast(configuration: .failed)
        }

        module.output.didDetectInsufficientMultichainFee = { [weak self, weak output = module.output] shortage in
            self?.handleNativeFeeShortage(shortage, onDepositClosed: {
                output?.refresh()
            })
        }

        module.output.didRequestOpenFeeRefill = { [weak self, weak output = module.output] extraType in
            if case let .multichain(token) = extraType {
                self?.depositFeeAsset(token, onDepositClosed: {
                    output?.refresh()
                })
                return
            }
            self?.handleFeeRefillRequest(extraType: extraType) {
                output?.refresh()
            }
        }

        router.push(viewController: module.view)
    }

    func handleNativeFeeShortage(
        _ shortage: MultichainNativeFeeShortage,
        onDepositClosed: @escaping () -> Void
    ) {
        nativeFeeShortagePopupPresenter.presentIfNeeded(
            shortage: shortage,
            from: router.rootViewController.topPresentedViewController(),
            onDeposit: { [weak self] asset in
                self?.depositFeeAsset(asset, onDepositClosed: onDepositClosed)
            }
        )
    }

    func depositFeeAsset(
        _ asset: MultichainAssetDetails,
        onDepositClosed: @escaping () -> Void
    ) {
        guard let didRequestFeeDeposit else {
            openReceive(for: asset, onClose: onDepositClosed)
            return
        }
        didRequestFeeDeposit(asset.assetId, onDepositClosed)
    }

    func openReceive(
        for asset: MultichainAssetDetails,
        onClose: @escaping () -> Void
    ) {
        guard let chain = asset.chain,
              let address = multichainState.walletAddress(
                  for: chain,
                  preferredType: wallet.preferredMultichainAddressType(for: chain)
              )
        else {
            return Log.w("deposit skipped - no receive address for fee asset \(asset.assetId)")
        }
        let coordinator = ReceiveModule(
            dependencies: .init(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).createReceiveCoordinator(
            router: router,
            wallet: wallet,
            address: ReceiveAddressPreview(address: address)
        )
        coordinator.didClose = { [weak self, weak coordinator] in
            self?.removeChild(coordinator)
            onClose()
        }
        addChild(coordinator)
        coordinator.start()
    }
}

private extension MultichainSendCoordinator {
    func logSendOpen() {
        analyticsProvider.log(SendOpen(from: sendSource.sendOpenFrom), utm: sendSource.utm)
    }

    func logSendClick(sendData: SendData) {
        guard let context = makeSendAnalyticsContext(sendData: sendData) else { return }
        analyticsProvider.log(SendClick(
            from: context.source.sendClickFrom,
            asset: context.asset,
            amount: context.amount
        ), utm: context.source.utm)
    }

    func logSendConfirm(model: TransactionConfirmationModel, context: MultichainSendAnalyticsContext?) {
        guard let context else { return }
        let feeAsset = feeAsset(model: model, context: context)
        analyticsProvider.log(SendConfirm(
            from: context.source.sendConfirmFrom,
            asset: context.asset,
            amount: context.amount,
            feeAsset: feeAsset,
            appId: context.source.appId
        ), utm: context.source.utm)
    }

    func logSendSuccess(
        model: TransactionConfirmationModel,
        context: MultichainSendAnalyticsContext?
    ) {
        guard let context else { return }
        let feeAsset = feeAsset(model: model, context: context)
        analyticsProvider.log(SendSuccess(
            from: context.source.sendSuccessFrom,
            asset: context.asset,
            amount: context.amount,
            feeAsset: feeAsset,
            appId: context.source.appId
        ), utm: context.source.utm)
    }

    func logSendFailed(
        model: TransactionConfirmationModel,
        error: any AnalyticsError,
        context: MultichainSendAnalyticsContext?
    ) {
        guard let context else { return }
        let feeAsset = feeAsset(model: model, context: context)
        analyticsProvider.log(SendFailed(
            from: context.source.sendFailedFrom,
            asset: context.asset,
            amount: context.amount,
            feeAsset: feeAsset,
            errorCode: error.code,
            errorMessage: error.message,
            appId: context.source.appId
        ), utm: context.source.utm)
    }

    func makeSendAnalyticsContext(sendData: SendData) -> MultichainSendAnalyticsContext? {
        guard case let .multichain(multichain) = sendData else {
            return nil
        }

        return MultichainSendAnalyticsContext(
            source: sendSource,
            asset: multichain.asset.asset.assetId,
            amount: amountDouble(
                value: multichain.amount,
                decimals: multichain.asset.asset.decimals
            )
        )
    }

    func amountDouble(value: BigUInt, decimals: Int) -> Double {
        NSDecimalNumber.fromBigUInt(value: value, decimals: decimals).doubleValue
    }

    func feeAsset(
        model: TransactionConfirmationModel,
        context: MultichainSendAnalyticsContext?
    ) -> FeeAsset {
        FeeAsset(extraState: model.extraState, asset: context?.asset)
    }

    func transferRedMetadata(
        context: MultichainSendAnalyticsContext?,
        feePaidIn: String? = nil
    ) -> RedAnalyticsMetadata? {
        context.flatMap { context in
            [
                .source: context.source.redSourceValue,
                .asset: context.asset,
                .amount: context.amount,
                .feePaidIn: feePaidIn,
                .appId: context.source.appId,
            ]
        }
    }
}
