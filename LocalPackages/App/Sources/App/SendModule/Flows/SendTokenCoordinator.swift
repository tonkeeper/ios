import BigInt
import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKScreenKit
import TKUIKit
import TonSwift
import TronSwift
import UIKit

private struct SendAnalyticsContext {
    let source: SendAnalyticsSource
    let assetNetwork: String
    let tokenSymbol: String
    let amount: Double
}

private enum SendFeePaidIn: String {
    case ton
    case trx
    case battery
    case gasless
    case free
}

final class SendTokenCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didSendSuccessfully: ((SendTokenCoordinator?) -> Void)?
    var didRequestOpenBuySell: ((_ isInternalPurchasing: Bool) -> Void)?

    private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?

    private let wallet: Wallet
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let recipientResolver: RecipientResolver
    private let sendItem: SendV3Item
    private let sendSource: SendAnalyticsSource
    private let recipient: Recipient?
    private let comment: String?
    private let analyticsProvider: AnalyticsProvider

    init(
        router: NavigationControllerRouter,
        wallet: Wallet,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        recipientResolver: RecipientResolver,
        sendItem: SendV3Item,
        sendSource: SendAnalyticsSource,
        recipient: Recipient? = nil,
        comment: String? = nil
    ) {
        self.wallet = wallet
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.recipientResolver = recipientResolver
        self.sendItem = sendItem
        self.sendSource = sendSource
        self.recipient = recipient
        self.comment = comment
        self.analyticsProvider = coreAssembly.analyticsProvider
        super.init(router: router)
    }

    override func start() {
        // If amount and recipient are set, we should force confirmation screen
        if isReadyForConfirmation(), let sendData = SendData.sendData(
            wallet: wallet,
            recipient: recipient,
            item: sendItem,
            comment: comment,
            isMaxAmount: false
        ) {
            logSendOpen()
            let context = makeSendAnalyticsContext(sendData: sendData)
            openSendConfirmation(sendData: sendData, analyticsContext: context)
        } else {
            openSend()
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

private extension SendTokenCoordinator {
    func openSend() {
        logSendOpen()
        let module = SendV3Assembly.module(
            wallet: wallet,
            item: sendItem,
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

        module.output.didTapPicker = { [weak self] wallet, token in
            var pickerToken: SendTokenPickerModel.PickerToken = .ton(.ton)
            switch token {
            case let .ton(ton):
                switch ton {
                case .nft: return
                case let .token(token, _):
                    pickerToken = .ton(token)
                }
            case let .tron(tron):
                switch tron {
                case .usdt:
                    pickerToken = .tronUSDT
                }
            }

            guard let self else { return }
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
                    guard let self else { return }
                    switch deeplink {
                    case let .transfer(data):
                        switch data {
                        case let .sendTransfer(sendTransferData):
                            let recipient = try await self.recipientResolver.resolverRecipient(
                                string: sendTransferData.recipient,
                                network: wallet.network
                            )
                            switch recipient {
                            case .ton:
                                module.input.setRecipient(string: sendTransferData.recipient)
                                module.input.setAmount(amount: sendTransferData.amount)
                                module.input.setComment(comment: sendTransferData.comment)
                            case .tron:
                                module.input.setRecipient(string: sendTransferData.recipient)
                                module.input.updateWithToken(.tron(.usdt(amount: sendTransferData.amount ?? 0)))
                                module.input.setComment(comment: sendTransferData.comment)
                            }
                        default: break
                        }
                    default: break
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

        router.push(viewController: module.view, animated: false)
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
                case .tronUSDT:
                    return .tron(.usdt(amount: 0))
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
        let scanModule = ScannerModule(
            dependencies: ScannerModule.Dependencies(
                coreAssembly: coreAssembly,
                scannerAssembly: keeperCoreMainAssembly.scannerAssembly()
            )
        ).createScannerModule(
            configurator: DefaultScannerControllerConfigurator(extensions: []),
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

private extension SendTokenCoordinator {
    func isReadyForConfirmation() -> Bool {
        switch sendItem {
        case let .ton(item):
            switch item {
            case let .token(_, amount):
                return !amount.isZero && recipient != nil && recipient?.isTon == true && recipient?.isCommentRequired == false
            case .nft:
                return recipient != nil && recipient?.isTon == true
            }
        case let .tron(item):
            switch item {
            case let .usdt(amount):
                return !amount.isZero && recipient != nil && recipient?.isTron == true
            }
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

    func openInsufficientFundsPopup(configuration: InfoPopupBottomSheetViewController.Configuration) {
        let viewController = InfoPopupBottomSheetViewController()
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
        viewController.configuration = configuration
        bottomSheetViewController.present(fromViewController: router.rootViewController)
    }

    func openSendConfirmation(sendData: SendData, analyticsContext: SendAnalyticsContext?) {
        enum AnalyticsTransactionDescriptor {
            case messageHash(String)
            case tronTxId(String)

            var stringValue: String {
                switch self {
                case let .messageHash(value):
                    value
                case let .tronTxId(value):
                    value
                }
            }
        }
        var transactionDescriptor: AnalyticsTransactionDescriptor?
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
                        isMaxAmount: ton.isMaxAmount
                    )
                case let .jetton(jettonItem):
                    transactionConfirmationController = keeperCoreMainAssembly.jettonTransferTransactionConfirmationController(
                        wallet: ton.wallet,
                        recipient: ton.recipient,
                        jettonItem: jettonItem,
                        amount: amount,
                        comment: ton.comment
                    )
                }
            case let .nft(nft):
                transactionConfirmationController = keeperCoreMainAssembly.nftTransferTransactionConfirmationController(
                    wallet: ton.wallet,
                    recipient: ton.recipient,
                    nft: nft,
                    comment: ton.comment
                )
            }
        case let .tron(tron):
            switch tron.item {
            case let .usdt(amount):
                let confirmationController = keeperCoreMainAssembly.tronUSDTTransferTransactionConfirmationController(
                    wallet: tron.wallet,
                    recipient: tron.recipient,
                    amount: amount
                )
                confirmationController.tronSignHandler = { [weak self, keeperCoreMainAssembly, coreAssembly] txId, wallet in
                    guard let self = self else { return nil }
                    transactionDescriptor = .tronTxId(txId.hexString())
                    let coordinator = TronUSDTTransferSignCoordinator(
                        router: ViewControllerRouter(rootViewController: router.rootViewController),
                        wallet: wallet,
                        txID: txId,
                        keeperCoreMainAssembly: keeperCoreMainAssembly,
                        coreAssembly: coreAssembly
                    )
                    let result = await coordinator.handleSign(parentCoordinator: self)
                    switch result {
                    case let .signed(signature):
                        return signature
                    case .cancel:
                        return nil
                    case let .failed(error):
                        throw error
                    }
                }
                transactionConfirmationController = confirmationController
            }
        }

        let module = TransactionConfirmationAssembly.module(
            transactionConfirmationController: transactionConfirmationController,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
        module.output.didRequireSign = { [weak self, keeperCoreMainAssembly, coreAssembly] walletTransfer, wallet in
            guard let self = self else { return nil }
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
            case let .signed(data):
                if case .tronTxId = transactionDescriptor {} else {
                    if let bocValue = data.first {
                        do {
                            let messageHash = try MessageHash.fromBocBase64(bocValue)
                            transactionDescriptor = .messageHash(messageHash)
                        } catch {
                            Log.w("Log 🪵: Failed to compute message hash: \(error)")
                            transactionDescriptor = .messageHash("boc:\(bocValue)")
                        }
                    }
                }
                return data
            case .cancel:
                return nil
            case let .failed(error):
                throw error
            }
        }

        module.output.didStartConfirmTransaction = { [weak self] model in
            self?.logSendConfirm(model: model, context: analyticsContext)
        }

        module.output.didClose = { [weak self] in
            self?.didFinish?(self)
        }

        module.output.didConfirmTransaction = { [weak self] model in
            self?.logSendSuccess(
                model: model,
                context: analyticsContext,
                transactionId: transactionDescriptor?.stringValue
            )
            self?.didSendSuccessfully?(self)
        }

        module.output.didFailTransaction = { [weak self] model, error in
            self?.logSendFailed(model: model, error: error, context: analyticsContext)
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

        router.push(viewController: module.view)
    }
}

private extension SendTokenCoordinator {
    func logSendOpen() {
        analyticsProvider.log(SendOpen(from: sendSource.sendOpenFrom))
    }

    func logSendClick(sendData: SendData) {
        guard let context = makeSendAnalyticsContext(sendData: sendData) else { return }
        analyticsProvider.log(SendClick(
            from: context.source.sendClickFrom,
            assetNetwork: context.assetNetwork,
            tokenSymbol: context.tokenSymbol,
            amount: context.amount
        ))
    }

    func logSendConfirm(model: TransactionConfirmationModel, context: SendAnalyticsContext?) {
        guard let context else { return }
        let feePaidIn = toSendConfirmFeePaidIn(feePaidInValue(model: model, assetNetwork: context.assetNetwork))
        analyticsProvider.log(SendConfirm(
            from: context.source.sendConfirmFrom,
            assetNetwork: context.assetNetwork,
            tokenSymbol: context.tokenSymbol,
            amount: context.amount,
            feePaidIn: feePaidIn,
            appId: context.source.appId
        ))
    }

    func logSendSuccess(
        model: TransactionConfirmationModel,
        context: SendAnalyticsContext?,
        transactionId: String?
    ) {
        guard let context else { return }
        let feePaidIn = toSendSuccessFeePaidIn(feePaidInValue(model: model, assetNetwork: context.assetNetwork))
        let transactionId = transactionId ?? "unknown"
        analyticsProvider.log(SendSuccess(
            from: context.source.sendSuccessFrom,
            assetNetwork: context.assetNetwork,
            tokenSymbol: context.tokenSymbol,
            amount: context.amount,
            feePaidIn: feePaidIn,
            transactionId: transactionId,
            appId: context.source.appId
        ))
    }

    func logSendFailed(
        model: TransactionConfirmationModel,
        error: Error,
        context: SendAnalyticsContext?
    ) {
        guard let context else { return }
        let feePaidIn = toSendFailedFeePaidIn(feePaidInValue(model: model, assetNetwork: context.assetNetwork))
        analyticsProvider.log(SendFailed(
            from: context.source.sendFailedFrom,
            assetNetwork: context.assetNetwork,
            tokenSymbol: context.tokenSymbol,
            amount: context.amount,
            feePaidIn: feePaidIn,
            errorCode: errorCode(from: error),
            errorMessage: errorMessage(from: error),
            appId: context.source.appId
        ))
    }

    func makeSendAnalyticsContext(sendData: SendData) -> SendAnalyticsContext? {
        switch sendData {
        case let .ton(ton):
            switch ton.item {
            case let .token(token, amount):
                let tokenSymbol: String
                let fractionDigits: Int
                switch token {
                case .ton:
                    tokenSymbol = TonInfo.symbol
                    fractionDigits = TonInfo.fractionDigits
                case let .jetton(jettonItem):
                    tokenSymbol = jettonItem.jettonInfo.symbol ?? jettonItem.jettonInfo.name
                    fractionDigits = jettonItem.jettonInfo.fractionDigits
                }
                let amountValue = amountDouble(value: amount, decimals: fractionDigits)
                return SendAnalyticsContext(
                    source: sendSource,
                    assetNetwork: "ton",
                    tokenSymbol: tokenSymbol,
                    amount: amountValue
                )
            case let .nft(nft):
                return SendAnalyticsContext(
                    source: sendSource,
                    assetNetwork: "ton",
                    tokenSymbol: nft.notNilName,
                    amount: 1
                )
            }
        case let .tron(tron):
            switch tron.item {
            case let .usdt(amount):
                let amountValue = amountDouble(value: amount, decimals: TronSwift.USDT.fractionDigits)
                return SendAnalyticsContext(
                    source: sendSource,
                    assetNetwork: "trc20",
                    tokenSymbol: TronSwift.USDT.symbol,
                    amount: amountValue
                )
            }
        }
    }

    func amountDouble(value: BigUInt, decimals: Int) -> Double {
        NSDecimalNumber.fromBigUInt(value: value, decimals: decimals).doubleValue
    }

    func feePaidInValue(model: TransactionConfirmationModel, assetNetwork: String) -> SendFeePaidIn {
        switch model.extraState {
        case let .extra(extra):
            switch extra.value {
            case .battery:
                return .battery
            case .gasless:
                return .gasless
            case .default:
                return assetNetwork == "trc20" ? .trx : .ton
            }
        case .none, .loading:
            return assetNetwork == "trc20" ? .trx : .ton
        }
    }

    func toSendConfirmFeePaidIn(_ value: SendFeePaidIn) -> SendConfirm.FeePaidIn {
        switch value {
        case .ton:
            return .ton
        case .trx:
            return .trx
        case .battery:
            return .battery
        case .gasless:
            return .gasless
        case .free:
            return .free
        }
    }

    func toSendSuccessFeePaidIn(_ value: SendFeePaidIn) -> SendSuccess.FeePaidIn {
        switch value {
        case .ton:
            return .ton
        case .trx:
            return .trx
        case .battery:
            return .battery
        case .gasless:
            return .gasless
        case .free:
            return .free
        }
    }

    func toSendFailedFeePaidIn(_ value: SendFeePaidIn) -> SendFailed.FeePaidIn {
        switch value {
        case .ton:
            return .ton
        case .trx:
            return .trx
        case .battery:
            return .battery
        case .gasless:
            return .gasless
        case .free:
            return .free
        }
    }

    func errorCode(from error: Error) -> Int {
        SendAnalyticsErrorMapper.errorCode(from: error)
    }

    func errorMessage(from error: Error) -> String {
        SendAnalyticsErrorMapper.errorMessage(from: error)
    }
}

private extension SendAnalyticsSource {
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
}
