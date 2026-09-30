import BigInt
import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKScreenKit
import TKUIKit
import TonSwift
import TronSwift
import UIKit

private struct SendAnalyticsContext {
    let source: SendAnalyticsSource
    let asset: String
    let amount: Double
}

private struct WithdrawAnalyticsContext {
    let from: RampSource
    let withdrawOption: WithdrawOption
    let sellAsset: String
    let stablecoinSymbol: String
    let buyAsset: String
    let asset: String
    let amount: Float
}

final class LegacySendTokenCoordinator: RouterCoordinator<NavigationControllerRouter>, SendCoordinator {
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
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let recipientResolver: RecipientResolver
    private let sendInput: SendInput
    private let sendSource: SendAnalyticsSource
    private let recipient: LegacyRecipient?
    private let comment: String?
    private let analyticsProvider: AnalyticsProvider
    private let transactionSentNotificationPatch: @Sendable (inout [String: Any]) -> Void

    init(
        router: NavigationControllerRouter,
        wallet: Wallet,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        recipientResolver: RecipientResolver,
        sendInput: SendInput,
        sendSource: SendAnalyticsSource,
        transactionSentNotificationPatch: @Sendable @escaping (inout [String: Any]) -> Void = { _ in },
        recipient: LegacyRecipient? = nil,
        comment: String? = nil
    ) {
        self.wallet = wallet
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.recipientResolver = recipientResolver
        self.sendInput = sendInput
        self.sendSource = sendSource
        self.recipient = recipient
        self.transactionSentNotificationPatch = transactionSentNotificationPatch
        self.comment = comment
        self.analyticsProvider = coreAssembly.analyticsProvider
        super.init(router: router)
    }

    override func start() {
        start(pushAnimated: false)
    }

    func start(pushAnimated: Bool) {
        // If amount and recipient are set, we should force confirmation screen (only for .direct)
        if case let .direct(sendItem) = sendInput,
           isReadyForConfirmation(sendItem: sendItem),
           let sendData = LegacySendData.make(
               wallet: wallet,
               recipient: recipient,
               item: sendItem,
               comment: comment,
               isMaxAmount: false
           )
        {
            logSendOpen()
            let context = makeSendAnalyticsContext(sendData: sendData)
            openSendConfirmation(sendData: sendData, analyticsContext: context)
        } else {
            openSend(pushAnimated: pushAnimated)
        }
    }

    func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
        guard let walletTransferSignCoordinator = walletTransferSignCoordinator else { return false }
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

private extension LegacySendTokenCoordinator {
    func openSend(pushAnimated: Bool = false) {
        logSendOpen()
        let module = SendV3Assembly.module(
            wallet: wallet,
            sendInput: sendInput,
            recipient: recipient,
            comment: comment,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        module.output.didContinueSend = { [weak self] sendData in
            self?.logSendClick(sendData: sendData)
            let context = self?.makeSendAnalyticsContext(sendData: sendData)
            self?.openSendConfirmation(sendData: sendData, analyticsContext: context)
        }

        module.output.didTapPicker = { [weak self] wallet, item in
            guard let self else { return }
            guard let pickerToken = self.selectedPickerToken(for: item) else {
                return
            }
            self.openTokenPicker(
                wallet: wallet,
                token: pickerToken,
                sourceViewController: self.router.rootViewController,
                completion: { token in
                    module.input.updateWithToken(token)
                }
            )
        }

        module.output.didTapScan = { [weak self] in
            self?.openScan(completion: { deeplink in
                Task { [weak self] in
                    guard let self, case let .transfer(.sendTransfer(data)) = deeplink else {
                        return
                    }
                    do {
                        let recipient = try await self.recipientResolver.resolverRecipient(
                            string: data.recipient,
                            network: wallet.network
                        )
                        switch recipient {
                        case .ton:
                            module.input.setRecipient(string: data.recipient)
                            module.input.setAmount(amount: data.amount)
                            module.input.setComment(comment: data.comment)
                        case .tron:
                            module.input.setRecipient(string: data.recipient)
                            module.input.updateWithToken(.tron(.usdt(amount: data.amount ?? 0)))
                            module.input.setComment(comment: data.comment)
                        }
                    } catch {
                        ToastPresenter.showToast(configuration: .init(title: TKLocales.Send.invalidAddress))
                    }
                }
            })
        }

        module.output.didTapClose = { [weak self] in
            self?.didFinish?(self)
        }

        module.output.didOpenURL = { [weak self] url in
            self?.openURL(url, title: nil)
        }

        router.push(viewController: module.view, animated: pushAnimated)
    }

    func openTokenPicker(
        wallet: Wallet,
        token: SendTokenPickerModel.PickerToken,
        sourceViewController: UIViewController,
        completion: @escaping (SendV3Item) -> Void
    ) {
        let model = SendTokenPickerModel(
            wallet: wallet,
            selectedToken: token,
            balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore
        )

        let module = TokenPickerAssembly.module(
            wallet: wallet,
            model: model,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        let bottomSheetViewController = TKBottomSheetViewController(
            contentViewController: module.view,
            ignoreBottomSafeArea: true
        )

        module.output.didSelectToken = { token in
            let sendToken: SendV3Item = {
                switch token {
                case let .ton(ton):
                    switch ton {
                    case .ton:
                        return .ton(.token(.ton, amount: 0))
                    case let .jetton(jettonInfo):
                        return .ton(.token(.jetton(jettonInfo), amount: 0))
                    }
                case .tron(.usdt):
                    return .tron(.usdt(amount: 0))
                case .tron(.trx):
                    return .tron(.trx(amount: 0))
                }
            }()
            completion(sendToken)
        }

        module.output.didFinish = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        bottomSheetViewController.present(fromViewController: sourceViewController)
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
                isMultichainEnabled: false
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

    func openURL(_ url: URL, title: String?) {
        let viewController = TKBridgeWebViewController(
            initialURL: url,
            initialTitle: nil,
            jsInjection: nil,
            configuration: .default
        )
        router.present(viewController)
    }
}

// MARK: - SendConfirmation

private extension LegacySendTokenCoordinator {
    func isReadyForConfirmation(sendItem: SendV3Item) -> Bool {
        switch sendItem {
        case let .ton(item):
            switch item {
            case let .token(_, amount):
                return !amount.isZero && recipient != nil && recipient?.isTon == true && recipient?.isCommentRequired == false
            case .nft:
                return recipient != nil && recipient?.isTon == true
            }
        case let .tron(item):
            return !item.amount.isZero && recipient != nil && recipient?.isTron == true
        }
    }

    func selectedPickerToken(for item: SendV3Item) -> SendTokenPickerModel.PickerToken? {
        switch item {
        case let .ton(ton):
            switch ton {
            case let .token(token, _):
                return .ton(token)
            case .nft:
                return nil
            }
        case let .tron(item):
            return .tron(item.token)
        }
    }

    func configureAndShowInsufficientPopup(
        wallet: Wallet,
        caption: String? = nil,
        buttonTitle: String,
        amount: BigUInt?,
        tokenSymbol: String?,
        fractionDigits: Int,
        balance: BigUInt,
        isInternalPurchasing: Bool
    ) {
        var buyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        buyButtonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(buttonTitle)
        )
        buyButtonConfiguration.action = { [weak self] in
            self?.router.dismiss(animated: true) {
                self?.didRequestOpenBuySell?(isInternalPurchasing)
                self?.didFinish?(self)
            }
        }

        let builder = InfoPopupBottomSheetConfigurationBuilder(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )
        let configuration = builder.insufficientTokenConfiguration(
            walletLabel: wallet.metaData.label,
            caption: caption,
            tokenSymbol: tokenSymbol ?? TonToken.ton.symbol,
            tokenFractionalDigits: fractionDigits,
            required: amount ?? 0,
            available: balance,
            buttons: [buyButtonConfiguration]
        )

        openInsufficientFundsPopup(configuration: configuration)
    }

    func showInsufficientTRXPopup(
        wallet: Wallet,
        balance: BigUInt,
        requiredAmount: BigUInt,
        onRefresh: @escaping () -> Void
    ) {
        let trxFeeToken = TronUSDTFeeOptionsResolver.trxFeeToken
        var getTrxButton = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        getTrxButton.content = TKButton.Configuration.Content(
            title: .plainString(TKLocales.TronUsdtFees.Common.Buttons.getTrx)
        )
        getTrxButton.action = { [weak self] in
            self?.router.dismiss(animated: true) {
                self?.handleFeeRefillRequest(
                    extraType: .gasless(token: trxFeeToken),
                    onRefresh: onRefresh
                )
            }
        }

        let builder = InfoPopupBottomSheetConfigurationBuilder(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )
        openInsufficientFundsPopup(
            configuration: builder.insufficientTokenConfiguration(
                walletLabel: wallet.metaData.label,
                caption: nil,
                tokenSymbol: TRX.symbol,
                tokenFractionalDigits: TRX.fractionDigits,
                required: requiredAmount,
                available: balance,
                buttons: [getTrxButton]
            )
        )
    }

    func openInsufficientFundsPopup(configuration: InfoPopupBottomSheetViewController.Configuration) {
        let viewController = InfoPopupBottomSheetViewController()
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
        viewController.configuration = configuration
        bottomSheetViewController.present(fromViewController: router.rootViewController)
    }

    func openSendConfirmation(sendData: LegacySendData, analyticsContext: SendAnalyticsContext?) {
        let withdrawAnalyticsContext = makeWithdrawAnalyticsContext(sendData: sendData)
        let transactionConfirmationController: TransactionConfirmationController
        switch sendData {
        case let .ton(ton):
            switch ton.item {
            case let .token(token, amount):
                switch token {
                case .ton:
                    transactionConfirmationController = keeperCoreMainAssembly.tonTransferTransactionConfirmationController(
                        wallet: ton.wallet,
                        recipient: ton.recipient,
                        amount: amount,
                        comment: ton.comment,
                        isMaxAmount: ton.isMaxAmount,
                        recipientDisplayAddress: ton.recipientDisplayAddress
                    )
                case let .jetton(jettonItem):
                    transactionConfirmationController = keeperCoreMainAssembly.jettonTransferTransactionConfirmationController(
                        wallet: ton.wallet,
                        recipient: ton.recipient,
                        jettonItem: jettonItem,
                        amount: amount,
                        comment: ton.comment,
                        recipientDisplayAddress: ton.recipientDisplayAddress
                    )
                }
            case let .nft(nft):
                transactionConfirmationController = keeperCoreMainAssembly.nftTransferTransactionConfirmationController(
                    wallet: ton.wallet,
                    recipient: ton.recipient,
                    nft: nft,
                    comment: ton.comment,
                    recipientDisplayAddress: ton.recipientDisplayAddress
                )
            }
        case let .tron(tron):
            let confirmationController = keeperCoreMainAssembly.tronTransferTransactionConfirmationController(
                wallet: tron.wallet,
                token: tron.item.token,
                recipient: tron.recipient,
                amount: tron.item.amount,
                recipientDisplayAddress: tron.recipientDisplayAddress
            )
            let tronSignHandler = { [weak self, keeperCoreMainAssembly, coreAssembly] (txId: TronSwift.TxID, wallet: Wallet) async throws(TronTransferSignError) in
                guard let self else {
                    throw .cancelled
                }
                let coordinator = TronUSDTTransferSignCoordinator(
                    router: ViewControllerRouter(rootViewController: router.rootViewController),
                    wallet: wallet,
                    txID: txId,
                    keeperCoreMainAssembly: keeperCoreMainAssembly,
                    coreAssembly: coreAssembly
                )
                return try await coordinator
                    .handleSign(parentCoordinator: self)
                    .get()
            }
            confirmationController.tronSignHandler = tronSignHandler
            transactionConfirmationController = confirmationController
        }

        let withdrawDisplayInfo: WithdrawDisplayInfo? = {
            guard case let .withdraw(sourceAsset, exchangeTo) = sendInput else { return nil }
            let estimatedDurationSeconds: Int? = switch sendData {
            case let .ton(ton): ton.estimatedDurationSeconds
            case let .tron(tron): tron.estimatedDurationSeconds
            }
            return WithdrawDisplayInfo(
                fromSymbol: sourceAsset.symbol,
                fromImageUrl: sourceAsset.image,
                fromNetworkName: sourceAsset.networkName,
                fromNetworkType: sourceAsset.network,
                symbol: exchangeTo.symbol,
                imageUrl: exchangeTo.image,
                networkName: exchangeTo.networkName,
                networkType: exchangeTo.network,
                estimatedDurationSeconds: estimatedDurationSeconds,
                withdrawalFeeUsd: exchangeTo.fee
            )
        }()

        let emulateMetadata = transferRedMetadata(context: analyticsContext)
        var emulateRedSession: RedAnalyticsSessionHolder?
        var sendRedSession: RedAnalyticsSessionHolder?

        let module = TransactionConfirmationAssembly.module(
            transactionConfirmationController: transactionConfirmationController,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            featureFlags: coreAssembly.featureFlags,
            transactionSentNotificationPatch: transactionSentNotificationPatch,
            withdrawDisplayInfo: withdrawDisplayInfo
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
            let feeAsset = FeeAsset(extraState: model.extraState, asset: analyticsContext?.asset)
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
            self.logWithdrawSendConfirm(model: model, context: withdrawAnalyticsContext)
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
            self.logSendSuccess(
                model: model,
                context: analyticsContext
            )
            self.logWithdrawSendSuccess(
                model: model,
                context: withdrawAnalyticsContext
            )
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

        module.output.didProduceInsufficientFundsError = { [weak self] error in
            guard let self else {
                return
            }

            let symbol: String
            let fractionDigits: Int
            let buttonTitle: String
            let caption: String?
            let amount: BigUInt
            let availableBalance: BigUInt
            let internalPurchasingFlow: Bool

            switch error {
            case .unknownJetton:
                ToastPresenter.showToast(configuration: .failed)
                return
            case let .tronFee(_, balance, requiredAmount):
                // TRX pays for a TRX transfer, so topping up is the only way out of this one.
                showInsufficientTRXPopup(
                    wallet: self.wallet,
                    balance: balance,
                    requiredAmount: requiredAmount,
                    onRefresh: { [weak output = module.output] in
                        output?.refresh()
                    }
                )
                return
            case let .blockchainFee(_, balance, requiredAmount):
                let tonToken = TonToken.ton
                let token = TonToken.ton
                symbol = token.symbol
                fractionDigits = token.fractionDigits
                amount = requiredAmount
                availableBalance = balance

                let amountFormatter = self.keeperCoreMainAssembly.formattersAssembly.amountFormatter
                let feeFormatted = amountFormatter.format(amount: amount, fractionDigits: tonToken.fractionDigits)
                let balanceFormatted = amountFormatter.format(amount: balance, fractionDigits: tonToken.fractionDigits)
                caption = TKLocales.InsufficientFunds.feeRequired(feeFormatted, balanceFormatted)
                buttonTitle = TKLocales.InsufficientFunds.buyTokenTitle(tonToken.symbol)

                internalPurchasingFlow = true
            case let .insufficientFunds(jettonInfo, balance, requiredAmount, _, isInternalPurchasing):
                caption = nil
                amount = requiredAmount
                availableBalance = balance

                if let jettonInfo {
                    fractionDigits = jettonInfo.fractionDigits
                    symbol = jettonInfo.symbol ?? jettonInfo.name
                    buttonTitle = TKLocales.InsufficientFunds.rechargeWallet
                } else {
                    fractionDigits = TonToken.ton.fractionDigits
                    symbol = TonToken.ton.symbol
                    buttonTitle = TKLocales.InsufficientFunds.buyTokenTitle(symbol)
                }

                internalPurchasingFlow = isInternalPurchasing
            }

            self.configureAndShowInsufficientPopup(
                wallet: self.wallet,
                caption: caption,
                buttonTitle: buttonTitle,
                amount: amount,
                tokenSymbol: symbol,
                fractionDigits: fractionDigits,
                balance: availableBalance,
                isInternalPurchasing: internalPurchasingFlow
            )
        }

        module.output.didRequestOpenFeeRefill = { [weak self, weak output = module.output] extraType in
            self?.handleFeeRefillRequest(extraType: extraType) {
                output?.refresh()
            }
        }

        router.push(viewController: module.view)
    }
}

private extension LegacySendTokenCoordinator {
    func logSendOpen() {
        analyticsProvider.log(SendOpen(from: sendSource.sendOpenFrom), utm: sendSource.utm)
    }

    func logSendClick(sendData: LegacySendData) {
        let context = makeSendAnalyticsContext(sendData: sendData)
        analyticsProvider.log(SendClick(
            from: context.source.sendClickFrom,
            asset: context.asset,
            amount: context.amount
        ), utm: context.source.utm)
    }

    func logSendConfirm(model: TransactionConfirmationModel, context: SendAnalyticsContext?) {
        guard let context else { return }
        let feeAsset = FeeAsset(extraState: model.extraState, asset: context.asset)
        analyticsProvider.log(SendConfirm(
            from: context.source.sendConfirmFrom,
            asset: context.asset,
            amount: context.amount,
            feeAsset: feeAsset,
            appId: context.source.appId
        ), utm: context.source.utm)
    }

    func logWithdrawSendConfirm(model: TransactionConfirmationModel, context: WithdrawAnalyticsContext?) {
        guard let context else { return }
        let feeAsset = FeeAsset(extraState: model.extraState, asset: context.asset)
        analyticsProvider.log(WithdrawSendConfirm(
            from: context.from,
            withdrawOption: context.withdrawOption,
            sellAsset: context.sellAsset,
            stablecoinSymbol: context.stablecoinSymbol,
            buyAsset: context.buyAsset,
            amount: context.amount,
            feeAsset: feeAsset
        ), utm: sendSource.utm)
    }

    func logSendSuccess(
        model: TransactionConfirmationModel,
        context: SendAnalyticsContext?
    ) {
        guard let context else { return }
        let feeAsset = FeeAsset(extraState: model.extraState, asset: context.asset)
        analyticsProvider.log(SendSuccess(
            from: context.source.sendSuccessFrom,
            asset: context.asset,
            amount: context.amount,
            feeAsset: feeAsset,
            appId: context.source.appId
        ), utm: context.source.utm)
    }

    func logWithdrawSendSuccess(
        model: TransactionConfirmationModel,
        context: WithdrawAnalyticsContext?
    ) {
        guard let context else { return }
        let feeAsset = FeeAsset(extraState: model.extraState, asset: context.asset)
        analyticsProvider.log(WithdrawSendSuccess(
            from: context.from,
            withdrawOption: context.withdrawOption,
            sellAsset: context.sellAsset,
            stablecoinSymbol: context.stablecoinSymbol,
            buyAsset: context.buyAsset,
            amount: context.amount,
            feeAsset: feeAsset
        ), utm: sendSource.utm)
    }

    func logSendFailed(
        model: TransactionConfirmationModel,
        error: any AnalyticsError,
        context: SendAnalyticsContext?
    ) {
        guard let context else { return }
        let feeAsset = FeeAsset(extraState: model.extraState, asset: context.asset)
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

    func makeSendAnalyticsContext(sendData: LegacySendData) -> SendAnalyticsContext {
        switch sendData {
        case let .ton(ton):
            switch ton.item {
            case let .token(token, amount):
                return SendAnalyticsContext(
                    source: sendSource,
                    asset: Token.ton(token).assetId(network: wallet.network),
                    amount: amountDouble(value: amount, decimals: token.fractionDigits)
                )
            case let .nft(nft):
                return SendAnalyticsContext(
                    source: sendSource,
                    asset: AssetId.nft(address: nft.address, network: wallet.network),
                    amount: 1
                )
            }
        case let .tron(tron):
            let token = tron.item.token
            return SendAnalyticsContext(
                source: sendSource,
                asset: Token.tron(token).assetId(network: wallet.network),
                amount: amountDouble(value: tron.item.amount, decimals: token.fractionDigits)
            )
        }
    }

    func makeWithdrawAnalyticsContext(sendData: LegacySendData) -> WithdrawAnalyticsContext? {
        guard
            let from = sendSource.withdrawSendConfirmFrom,
            let withdrawOption = withdrawSendOption(),
            case let .withdraw(sourceAsset, exchangeTo) = sendInput,
            let sellAsset = sourceAsset.withdrawAnalyticsAssetIdentifier,
            let buyAsset = exchangeTo.withdrawAnalyticsAssetIdentifier
        else {
            return nil
        }

        let sendContext = makeSendAnalyticsContext(sendData: sendData)
        return WithdrawAnalyticsContext(
            from: from,
            withdrawOption: withdrawOption,
            sellAsset: sellAsset,
            stablecoinSymbol: sourceAsset.symbol,
            buyAsset: buyAsset,
            asset: sendContext.asset,
            amount: sendAmount(sendData)
        )
    }

    func sendAmount(_ sendData: LegacySendData) -> Float {
        switch sendData {
        case let .ton(ton):
            switch ton.item {
            case let .token(token, amount):
                return Float(amountDouble(value: amount, decimals: token.fractionDigits))
            case .nft:
                return 1
            }
        case let .tron(tron):
            return Float(amountDouble(value: tron.item.amount, decimals: tron.item.token.fractionDigits))
        }
    }

    func withdrawSendOption() -> WithdrawOption? {
        switch sendInput {
        case .direct:
            return nil
        case .withdraw:
            return .getUsdtOtherNetworks
        }
    }

    func amountDouble(value: BigUInt, decimals: Int) -> Double {
        NSDecimalNumber.fromBigUInt(value: value, decimals: decimals).doubleValue
    }

    func transferRedMetadata(
        context: SendAnalyticsContext?,
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

extension SendAnalyticsSource {
    var transactionOrigin: TransactionOrigin {
        TransactionOrigin(initiatedBy: initiatedBy, appId: appId, utm: utm)
    }

    var utm: UtmParameters {
        switch self {
        case let .deepLink(utm):
            return utm
        case .walletScreen, .jettonScreen, .tonconnectLocal, .tonconnectRemote, .qrCode:
            return .empty
        }
    }

    var initiatedBy: InitiatedBy {
        switch self {
        case .walletScreen, .jettonScreen:
            .user
        case .deepLink:
            .deepLink
        case .tonconnectLocal:
            .tonconnectLocal
        case .tonconnectRemote:
            .tonconnectRemote
        case .qrCode:
            .qrCode
        }
    }

    var appId: String? {
        switch self {
        case let .tonconnectLocal(appId):
            return appId
        case .walletScreen, .jettonScreen, .deepLink, .tonconnectRemote, .qrCode:
            return nil
        }
    }

    var sendOpenFrom: SendOpen.From {
        switch self {
        case .walletScreen:
            return .walletScreen
        case .jettonScreen:
            return .jettonScreen
        case .deepLink:
            return .deepLink
        case .tonconnectLocal:
            return .tonconnectLocal
        case .tonconnectRemote:
            return .tonconnectRemote
        case .qrCode:
            return .qrCode
        }
    }

    var sendClickFrom: SendClick.From {
        switch self {
        case .walletScreen:
            return .walletScreen
        case .jettonScreen:
            return .jettonScreen
        case .deepLink:
            return .deepLink
        case .tonconnectLocal:
            return .tonconnectLocal
        case .tonconnectRemote:
            return .tonconnectRemote
        case .qrCode:
            return .qrCode
        }
    }

    var sendConfirmFrom: SendConfirm.From {
        switch self {
        case .walletScreen:
            return .walletScreen
        case .jettonScreen:
            return .jettonScreen
        case .deepLink:
            return .deepLink
        case .tonconnectLocal:
            return .tonconnectLocal
        case .tonconnectRemote:
            return .tonconnectRemote
        case .qrCode:
            return .qrCode
        }
    }

    var sendSuccessFrom: SendSuccess.From {
        switch self {
        case .walletScreen:
            return .walletScreen
        case .jettonScreen:
            return .jettonScreen
        case .deepLink:
            return .deepLink
        case .tonconnectLocal:
            return .tonconnectLocal
        case .tonconnectRemote:
            return .tonconnectRemote
        case .qrCode:
            return .qrCode
        }
    }

    var sendFailedFrom: SendFailed.From {
        switch self {
        case .walletScreen:
            return .walletScreen
        case .jettonScreen:
            return .jettonScreen
        case .deepLink:
            return .deepLink
        case .tonconnectLocal:
            return .tonconnectLocal
        case .tonconnectRemote:
            return .tonconnectRemote
        case .qrCode:
            return .qrCode
        }
    }

    var withdrawSendConfirmFrom: RampSource? {
        switch self {
        case .walletScreen:
            return .walletScreen
        case .jettonScreen:
            return .jettonScreen
        case .deepLink:
            return .deepLink
        case .qrCode:
            return .qrCode
        case .tonconnectLocal, .tonconnectRemote:
            return nil
        }
    }

    var redAttemptSource: RedAnalyticsAttemptSource {
        switch self {
        case .tonconnectLocal:
            return .tonconnectLocal
        case .tonconnectRemote:
            return .tonconnectRemote
        case .walletScreen, .jettonScreen, .deepLink, .qrCode:
            return .nativeUI
        }
    }

    var redSourceValue: String {
        switch self {
        case .walletScreen:
            return "wallet_screen"
        case .jettonScreen:
            return "jetton_screen"
        case .deepLink:
            return "deep_link"
        case .tonconnectLocal:
            return RedAnalyticsAttemptSource.tonconnectLocal.rawValue
        case .tonconnectRemote:
            return RedAnalyticsAttemptSource.tonconnectRemote.rawValue
        case .qrCode:
            return "qr_code"
        }
    }
}
