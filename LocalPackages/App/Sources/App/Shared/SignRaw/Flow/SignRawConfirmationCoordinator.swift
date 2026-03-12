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
public final class SignRawConfirmationCoordinator: RouterCoordinator<WindowRouter> {
    var didRequireSign: ((TransferData, Wallet, UIViewController) async throws -> SignedTransactions?)?
    var didRequestShowInfoPopup: ((_ title: String, _ caption: String) -> Void)?
    var didRequestReplanishWallet: ((_ wallet: Wallet, _ isInternalPurchasing: Bool) -> Void)?

    private let wallet: Wallet
    private let transferProvider: () async throws -> Transfer
    private let resultHandler: SignRawControllerResultHandler?
    private let sendFrom: SendOpen.From
    private let appId: String?
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private var lastSendAnalyticsPayload: SignRawSendAnalyticsPayload?

    public init(
        router: WindowRouter,
        wallet: Wallet,
        transferProvider: @escaping () async throws -> Transfer,
        resultHandler: SignRawControllerResultHandler?,
        sendFrom: SendOpen.From,
        appId: String?,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) {
        self.wallet = wallet
        self.transferProvider = transferProvider
        self.resultHandler = resultHandler
        self.sendFrom = sendFrom
        self.appId = appId
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

    override public func start() {
        openConfirmation()
    }

    private func openConfirmation() {
        let rootViewController = UIViewController()
        router.window.rootViewController = rootViewController
        router.window.makeKeyAndVisible()

        let module = SignRawConfirmationAssembly.module(
            wallet: wallet,
            transferProvider: transferProvider,
            resultHandler: SignRawAnalyticsResultHandler(
                base: resultHandler,
                analyticsProvider: coreAssembly.analyticsProvider,
                payloadProvider: { [weak self] in self?.lastSendAnalyticsPayload },
                errorMapper: { [weak self] in self?.errorCode(from: $0) ?? 0 },
                errorMessageMapper: { [weak self] in self?.errorMessage(from: $0) ?? "" },
                sendFrom: sendFrom,
                appId: resolvedAppId
            ),
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        weak let moduleInput = module.input
        let containerViewController = TKBottomSheetViewController(contentViewController: module.view)
        containerViewController.didClose = { [weak self] isInteractivly in
            guard let self else { return }
            guard isInteractivly else { return }
            moduleInput?.cancel()
            self.didFinish?(self)
        }

        module.output.didRequireSign = { [weak self] transferData, wallet in
            guard let self else { return nil }
            return try await didRequireSign?(transferData, wallet, containerViewController)
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
        module.output.didRequestSendConfirm = { [weak self] payload in
            guard let self else { return }
            lastSendAnalyticsPayload = payload
            logSendConfirm(payload: payload)
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
        coreAssembly.analyticsProvider.log(SendOpen(from: sendFrom))
    }

    private func logSendConfirm(payload: SignRawSendAnalyticsPayload) {
        coreAssembly.analyticsProvider.log(SendConfirm(
            from: sendFrom.sendConfirmFrom,
            assetNetwork: payload.assetNetwork,
            tokenSymbol: payload.tokenSymbol,
            amount: payload.amount,
            feePaidIn: toSendConfirmFeePaidIn(payload.feePaidIn),
            appId: resolvedAppId
        ))
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

    private func toSendConfirmFeePaidIn(_ value: SignRawSendAnalyticsPayload.FeePaidIn) -> SendConfirm.FeePaidIn {
        switch value {
        case .ton:
            return .ton
        case .battery:
            return .battery
        case .gasless:
            return .gasless
        }
    }

    private func errorCode(from error: Error) -> Int {
        SendAnalyticsErrorMapper.errorCode(from: error)
    }

    private func errorMessage(from error: Error) -> String {
        SendAnalyticsErrorMapper.errorMessage(from: error)
    }

    private var resolvedAppId: String? {
        sendFrom.requiresAppId ? appId : nil
    }
}

private struct SignRawAnalyticsResultHandler: SignRawControllerResultHandler {
    let base: SignRawControllerResultHandler?
    let analyticsProvider: AnalyticsProvider
    let payloadProvider: () -> SignRawSendAnalyticsPayload?
    let errorMapper: (Error) -> Int
    let errorMessageMapper: (Error) -> String
    let sendFrom: SendOpen.From
    let appId: String?

    func didConfirm(boc: String) {
        if let payload = payloadProvider() {
            let transactionId: String
            do {
                transactionId = try MessageHash.fromBocBase64(boc)
            } catch {
                Log.w("Log 🪵: Failed to compute message hash: \(error)")
                transactionId = "boc:\(boc)"
            }
            analyticsProvider.log(SendSuccess(
                from: sendFrom.sendSuccessFrom,
                assetNetwork: payload.assetNetwork,
                tokenSymbol: payload.tokenSymbol,
                amount: payload.amount,
                feePaidIn: toSendSuccessFeePaidIn(payload.feePaidIn),
                transactionId: transactionId,
                appId: resolvedAppId
            ))
        }
        base?.didConfirm(boc: boc)
    }

    func didFail(error: Error) {
        if let payload = payloadProvider() {
            analyticsProvider.log(SendFailed(
                from: sendFrom.sendFailedFrom,
                assetNetwork: payload.assetNetwork,
                tokenSymbol: payload.tokenSymbol,
                amount: payload.amount,
                feePaidIn: toSendFailedFeePaidIn(payload.feePaidIn),
                errorCode: errorMapper(error),
                errorMessage: errorMessageMapper(error),
                appId: resolvedAppId
            ))
        }
        base?.didFail(error: error)
    }

    func didCancel() {
        base?.didCancel()
    }

    private func toSendSuccessFeePaidIn(_ value: SignRawSendAnalyticsPayload.FeePaidIn) -> SendSuccess.FeePaidIn {
        switch value {
        case .ton:
            return .ton
        case .battery:
            return .battery
        case .gasless:
            return .gasless
        }
    }

    private func toSendFailedFeePaidIn(_ value: SignRawSendAnalyticsPayload.FeePaidIn) -> SendFailed.FeePaidIn {
        switch value {
        case .ton:
            return .ton
        case .battery:
            return .battery
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
