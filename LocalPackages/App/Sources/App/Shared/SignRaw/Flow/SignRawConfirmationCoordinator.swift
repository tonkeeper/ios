import BigInt
import KeeperCore
import SignRaw
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

@MainActor
final class SignRawConfirmationCoordinator: RouterCoordinator<WindowRouter> {
    var didRequireSign: ((TransferData, Wallet, UIViewController) async throws(WalletTransferSignError) -> SignedTransactions)?
    var didRequestReplanishWallet: ((_ wallet: Wallet, _ isInternalPurchasing: Bool) -> Void)?

    private let wallet: Wallet
    private let transferProvider: () async throws -> Transfer
    private let resultHandler: SignRawControllerResultHandler?
    private let sendFrom: SendOpen.From
    private let appId: String?
    private let initiatedBy: InitiatedBy
    private let dappUrl: String?
    private let utm: UtmParameters
    private let redAnalyticsConfiguration: RedAnalyticsConfiguration?
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private var lastSendAnalyticsPayload: SignRawSendAnalyticsPayload?
    private var lastEmulatedTransaction: SignRawEmulatedTransaction?

    init(
        router: WindowRouter,
        wallet: Wallet,
        transferProvider: @escaping () async throws -> Transfer,
        resultHandler: SignRawControllerResultHandler?,
        sendFrom: SendOpen.From,
        appId: String?,
        initiatedBy: InitiatedBy,
        dappUrl: String?,
        utm: UtmParameters = .empty,
        redAnalyticsConfiguration: RedAnalyticsConfiguration? = nil,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) {
        self.wallet = wallet
        self.transferProvider = transferProvider
        self.resultHandler = resultHandler
        self.sendFrom = sendFrom
        self.appId = appId
        self.initiatedBy = initiatedBy
        self.dappUrl = dappUrl
        self.utm = utm
        self.redAnalyticsConfiguration = redAnalyticsConfiguration
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        let hasValidAppId = appId?.isEmpty == false
        if sendFrom.requiresAppId, !hasValidAppId {
            Log.signRaw.e("Missing appId for tonconnect_local", extraInfo: [
                "send_from": sendFrom.rawValue,
            ])
        }
        super.init(router: router)
    }

    override func start() {
        openConfirmation()
    }

    private func didRequireSignHandler(
        transferData: TransferData,
        wallet: Wallet,
        containerViewController: UIViewController
    ) async throws(SignRawSignFailure) -> SignedTransactions {
        guard let didRequireSign else {
            throw .canceled
        }
        do {
            return try await didRequireSign(
                transferData,
                wallet,
                containerViewController
            )
        } catch {
            switch error {
            case .cancelled:
                throw .canceled
            default:
                throw .failedToSign(
                    message: "transfer failure: \(error.localizedDescription)"
                )
            }
        }
    }

    private func openConfirmation() {
        let rootViewController = UIViewController()
        router.window.rootViewController = rootViewController
        router.window.makeKeyAndVisible()
        let redSession = redAnalyticsConfiguration.map { _ in
            RedAnalyticsSessionHolder(
                analytics: coreAssembly.analyticsProvider
            )
        }

        let module = SignRawConfirmationAssembly.module(
            wallet: wallet,
            transferProvider: transferProvider,
            resultHandler: SignRawAnalyticsResultHandler(
                base: resultHandler,
                analyticsProvider: coreAssembly.analyticsProvider,
                payloadProvider: { [weak self] in self?.lastSendAnalyticsPayload },
                emulatedTransactionProvider: { [weak self] in self?.lastEmulatedTransaction },
                sendFrom: sendFrom,
                appId: resolvedAppId,
                origin: TransactionOrigin(
                    initiatedBy: initiatedBy,
                    appId: resolvedAppId,
                    dappUrl: dappUrl,
                    utm: utm
                ),
                redSession: redSession,
                wallet: wallet
            ),
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            featureFlags: coreAssembly.featureFlags
        )

        weak let moduleInput = module.input
        let containerViewController = TKBottomSheetViewController(contentViewController: module.view)
        containerViewController.didClose = { [weak self] isInteractivly in
            guard let self else { return }
            guard isInteractivly else { return }
            moduleInput?.cancel()
            redSession?.finish(
                outcome: .cancel,
                stage: "confirm"
            )
            self.didFinish?(self)
        }

        module.output.didRequireSign = { [weak self] transferData, wallet throws(SignRawSignFailure) in
            guard let self else {
                throw .canceled
            }
            return try await didRequireSignHandler(
                transferData: transferData,
                wallet: wallet,
                containerViewController: containerViewController
            )
        }
        module.output.didConfirm = { [weak self] in
            guard let self else { return }
            self.didFinish?(self)
        }
        module.output.didRequestSendOpen = { [weak self] payload in
            guard let self else { return }
            lastSendAnalyticsPayload = payload
            logSendOpen()
        }
        module.output.didRequestConfirm = { [weak self] payload in
            guard let self else { return }
            if let redAnalyticsConfiguration {
                redSession?.start(
                    flow: redAnalyticsConfiguration.flow,
                    operation: redAnalyticsConfiguration.operation,
                    attemptSource: redAnalyticsConfiguration.attemptSource,
                    otherMetadata: redAnalyticsConfiguration.staticMetadata.merging(
                        [
                            .appId: resolvedAppId,
                        ]
                    ) { _, newValue in newValue }
                )
            }
            switch payload {
            case let .send(sendPayload, emulation, transferType):
                lastSendAnalyticsPayload = sendPayload
                lastEmulatedTransaction = SignRawEmulatedTransaction(
                    emulation: emulation,
                    transferType: transferType
                )
                logSendConfirm(payload: sendPayload)
            case let .general(emulation, transferType):
                lastEmulatedTransaction = SignRawEmulatedTransaction(
                    emulation: emulation,
                    transferType: transferType
                )
            }
        }
        module.output.didCancelAttempt = {
            redSession?.finish(
                outcome: .cancel,
                stage: "confirm"
            )
        }
        module.output.didCancel = { [weak self] in
            guard let self else { return }
            self.didFinish?(self)
        }
        module.output.didRequestShowInfoPopup = { [weak self] title, caption in
            self?.openInfoPopup(title: title, caption: caption)
        }
        module.output.didRequireShowInsufficientPopup = { [weak self, weak containerViewController] wallet, error in
            guard let self else { return }
            let symbol: String
            let fractionDigits: Int
            let buttonTitle: String
            let caption: String?
            let amount: BigUInt
            let availableBalance: BigUInt
            let internalPurchasingFlow: Bool

            switch error {
            // Raised for a TRX transfer only, which this flow never performs.
            case .tronFee:
                return
            case let .blockchainFee(_, balance, requiredAmount):
                let token = TonToken.ton
                symbol = token.symbol
                fractionDigits = token.fractionDigits
                amount = requiredAmount
                availableBalance = balance

                let amountFormatter = self.keeperCoreMainAssembly.formattersAssembly.amountFormatter
                let feeFormatted = amountFormatter.format(amount: amount, fractionDigits: fractionDigits)
                let balanceFormatted = amountFormatter.format(amount: balance, fractionDigits: fractionDigits)
                caption = TKLocales.InsufficientFunds.feeRequired(feeFormatted, balanceFormatted)
                buttonTitle = TKLocales.InsufficientFunds.buyTokenTitle(token.symbol)
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
            case .unknownJetton:
                return
            }

            moduleInput?.cancel()
            containerViewController?.dismiss {
                self.startInsufficientFlow(
                    wallet: wallet,
                    caption: caption,
                    buttonTitle: buttonTitle,
                    symbol: symbol,
                    fractionDigits: fractionDigits,
                    required: amount,
                    available: availableBalance,
                    isInternalPurchasing: internalPurchasingFlow
                )
            }
        }

        containerViewController.present(fromViewController: rootViewController)
    }

    private func logSendOpen() {
        coreAssembly.analyticsProvider.log(SendOpen(from: sendFrom), utm: utm)
    }

    private func logSendConfirm(payload: SignRawSendAnalyticsPayload) {
        coreAssembly.analyticsProvider.log(SendConfirm(
            from: sendFrom.sendConfirmFrom,
            asset: payload.asset,
            amount: payload.amount,
            feeAsset: feeAsset(payload.feePaidIn),
            appId: resolvedAppId
        ), utm: utm)
    }

    private func openInfoPopup(title: String, caption: String) {
        guard let rootViewController = router.window.rootViewController?.presentedViewController else {
            return
        }

        let viewController = InfoPopupBottomSheetViewController()
        let sheetViewController = TKBottomSheetViewController(contentViewController: viewController)

        var button = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        button.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.ok))
        button.action = { [weak sheetViewController] in
            sheetViewController?.dismiss()
        }

        let configurationBuilder = InfoPopupBottomSheetConfigurationBuilder(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )
        let configuration = configurationBuilder.commonConfiguration(
            title: title, caption: caption, buttons: [button]
        )
        viewController.configuration = configuration
        sheetViewController.present(fromViewController: rootViewController)
    }

    @MainActor
    private func startInsufficientFlow(
        wallet: Wallet,
        caption: String?,
        buttonTitle: String,
        symbol: String,
        fractionDigits: Int,
        required: BigUInt,
        available: BigUInt,
        isInternalPurchasing: Bool
    ) {
        guard let rootViewController = router.window.rootViewController else {
            return
        }

        let viewController = InfoPopupBottomSheetViewController()
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
        let configurationBuilder = InfoPopupBottomSheetConfigurationBuilder(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )

        var buyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        buyButtonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(buttonTitle)
        )
        buyButtonConfiguration.action = { [weak bottomSheetViewController, weak self] in
            bottomSheetViewController?.dismiss {
                self?.didRequestReplanishWallet?(wallet, isInternalPurchasing)
                self?.didFinish?(self)
            }
        }

        bottomSheetViewController.didClose = { [weak self] _ in
            self?.didFinish?(self)
        }
        let configuration = configurationBuilder.insufficientTokenConfiguration(
            walletLabel: wallet.metaData.label,
            caption: caption,
            tokenSymbol: symbol,
            tokenFractionalDigits: fractionDigits,
            required: required,
            available: available,
            buttons: [buyButtonConfiguration]
        )
        viewController.configuration = configuration
        ToastPresenter.hideAll()
        bottomSheetViewController.present(fromViewController: rootViewController)
    }

    private func feeAsset(_ value: SignRawSendAnalyticsPayload.FeePaidIn) -> FeeAsset {
        switch value {
        case .ton:
            return .coin
        case .battery:
            return .batteryCharges
        case .gasless:
            return .gasless
        }
    }

    private var resolvedAppId: String? {
        sendFrom.requiresAppId ? appId : nil
    }
}

private struct SignRawAnalyticsResultHandler: SignRawControllerResultHandler {
    let base: SignRawControllerResultHandler?
    let analyticsProvider: AnalyticsProvider
    let payloadProvider: () -> SignRawSendAnalyticsPayload?
    let emulatedTransactionProvider: () -> SignRawEmulatedTransaction?
    let sendFrom: SendOpen.From
    let appId: String?
    let origin: TransactionOrigin
    let redSession: RedAnalyticsSessionHolder?
    let wallet: Wallet

    func didConfirm(boc: String) {
        if let payload = payloadProvider() {
            analyticsProvider.log(SendSuccess(
                from: sendFrom.sendSuccessFrom,
                asset: payload.asset,
                amount: payload.amount,
                feeAsset: feeAsset(payload.feePaidIn),
                appId: resolvedAppId
            ), utm: origin.utm)
        }
        if let event = transactionSentEvent() {
            analyticsProvider.log(event, utm: origin.utm)
        }
        redSession?.finish(
            outcome: .success,
            stage: "send"
        )
        base?.didConfirm(boc: boc)
    }

    func didFail(error: SomeOf<TransferError, TransactionConfirmationError>) {
        if let payload = payloadProvider() {
            analyticsProvider.log(SendFailed(
                from: sendFrom.sendFailedFrom,
                asset: payload.asset,
                amount: payload.amount,
                feeAsset: feeAsset(payload.feePaidIn),
                errorCode: error.code,
                errorMessage: error.message,
                appId: resolvedAppId
            ), utm: origin.utm)
        }
        redSession?.finish(
            outcome: .fail,
            error: error,
            stage: "send"
        )
        base?.didFail(error: error)
    }

    func didCancel() {
        redSession?.finish(
            outcome: .cancel,
            stage: "confirm"
        )
        base?.didCancel()
    }

    private func transactionSentEvent() -> TransactionSent? {
        guard let emulated = emulatedTransactionProvider() else {
            return TransactionSent(
                wallet: wallet,
                callDetail: .unknown,
                callAmount: 0,
                feeAsset: .coin,
                origin: origin
            )
        }
        return TransactionSent(
            wallet: wallet,
            emulation: emulated.emulation,
            transferType: emulated.transferType,
            origin: origin
        )
    }

    private func feeAsset(_ value: SignRawSendAnalyticsPayload.FeePaidIn) -> FeeAsset {
        switch value {
        case .ton:
            return .coin
        case .battery:
            return .batteryCharges
        case .gasless:
            return .gasless
        }
    }

    private var resolvedAppId: String? {
        sendFrom.requiresAppId ? appId : nil
    }
}

private extension SendOpen.From {
    var sendConfirmFrom: SendConfirm.From {
        SendConfirm.From(rawValue: rawValue) ?? .tonconnectRemote
    }

    var sendSuccessFrom: SendSuccess.From {
        SendSuccess.From(rawValue: rawValue) ?? .tonconnectRemote
    }

    var sendFailedFrom: SendFailed.From {
        SendFailed.From(rawValue: rawValue) ?? .tonconnectRemote
    }

    var requiresAppId: Bool {
        self == .tonconnectLocal
    }
}

private struct SignRawEmulatedTransaction {
    let emulation: SignRawEmulation
    let transferType: TransferType
}
