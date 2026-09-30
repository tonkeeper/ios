import BigInt
import Foundation
import KeeperCore
import TKCore
import TKFeatureFlags
import TKLocalize
import TKLogging
import TKUIKit
import TonSwift
import TronSwift
import UIKit

@MainActor
protocol NativeSwapTransactionConfirmationModuleOutput: AnyObject {
    var didRequireSign: ((TransferData, Wallet) async throws(WalletTransferSignError) -> SignedTransactions)? { get set }
    var didConfirmTransaction: (() -> Void)? { get set }
    var didClose: (() -> Void)? { get set }
    var didTapEdit: ((Bool?) -> Void)? { get set }
    var didProduceInsufficientFundsError: ((InsufficientFundsError) -> Void)? { get set }
    var didProduceTonSwapInsufficientFeeError: ((_ requiredFee: BigUInt, _ balance: BigUInt) -> Void)? { get set }
}

@MainActor
protocol NativeSwapTransactionConfirmationViewModel: AnyObject {
    var didTapPop: (() -> Void)? { get set }
    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }
    var didRequestSendAllConfirmation: ((String, @escaping (Bool) -> Void) -> Void)? { get set }
    var didRequestSlippageInfo: ((UIView) -> Void)? { get set }
    var didRequestValueDifferenceInfo: ((UIView) -> Void)? { get set }
    var didRequestTemporaryReserveInfo: ((String, UIView) -> Void)? { get set }
    var didRequestBatteryTemporaryReserveInfo: ((String, UIView) -> Void)? { get set }

    func viewDidLoad()
    func viewDidAppear()
    func viewDidDisappear()
    func didTapCloseButton()
}

@MainActor
final class NativeSwapTransactionConfirmationViewModelImplementation: NativeSwapTransactionConfirmationViewModel, NativeSwapTransactionConfirmationModuleOutput {
    var didTapEdit: ((Bool?) -> Void)?
    var didTapPop: (() -> Void)?
    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?
    var didRequestSendAllConfirmation: ((String, @escaping (Bool) -> Void) -> Void)?
    var didRequestSlippageInfo: ((UIView) -> Void)?
    var didRequestValueDifferenceInfo: ((UIView) -> Void)?
    var didRequestTemporaryReserveInfo: ((String, UIView) -> Void)?
    var didRequestBatteryTemporaryReserveInfo: ((String, UIView) -> Void)?
    var didProduceInsufficientFundsError: ((InsufficientFundsError) -> Void)?
    var didProduceTonSwapInsufficientFeeError: ((_ requiredFee: BigUInt, _ balance: BigUInt) -> Void)?

    var didRequireSign: ((TransferData, Wallet) async throws(WalletTransferSignError) -> SignedTransactions)?
    var didConfirmTransaction: (() -> Void)?
    var didClose: (() -> Void)?

    private enum State {
        case idle
        case processing
        case success
        case failed
    }

    private var state: State = .idle {
        didSet {
            update(with: confirmationController.getModel())
        }
    }

    private let wallet: Wallet
    private let confirmationController: TransactionConfirmationController
    private let pendingTransactionsService: PendingTransactionsService
    private let sendController: SendV3Controller
    private let amountFormatter: AmountFormatter
    private let fundsValidator: InsufficientFundsValidator
    private let currencyStore: CurrencyStore
    private let nativeSwapService: NativeSwapService
    private let batteryCalculation: BatteryCalculation
    private let configurationAssembly: ConfigurationAssembly
    private let configuration: Configuration
    private let analyticsProvider: AnalyticsProvider

    private var model: NativeSwapTransactionConfirmationModel

    private var updateTask: Task<Void, Never>?
    private var confirmTask: Task<Void, Never>?

    init(
        wallet: Wallet,
        sendController: SendV3Controller,
        confirmationController: TransactionConfirmationController,
        pendingTransactionsService: PendingTransactionsService,
        model: NativeSwapTransactionConfirmationModel,
        amountFormatter: AmountFormatter,
        fundsValidator: InsufficientFundsValidator,
        currencyStore: CurrencyStore,
        nativeSwapService: NativeSwapService,
        batteryCalculation: BatteryCalculation,
        configurationAssembly: ConfigurationAssembly,
        configuration: Configuration,
        analyticsProvider: AnalyticsProvider
    ) {
        self.wallet = wallet
        self.sendController = sendController
        self.confirmationController = confirmationController
        self.pendingTransactionsService = pendingTransactionsService
        self.model = model
        self.amountFormatter = amountFormatter
        self.fundsValidator = fundsValidator
        self.currencyStore = currencyStore
        self.nativeSwapService = nativeSwapService
        self.batteryCalculation = batteryCalculation
        self.configurationAssembly = configurationAssembly
        self.configuration = configuration
        self.analyticsProvider = analyticsProvider
        self.model.rateFormatted = getExchangeRateForOneToken()
    }

    func viewDidLoad() {
        if let controller = confirmationController as? NativeSwapTransactionConfirmationController {
            controller.updateConfirmation(model.confirmation)
        }

        confirmationController.signHandler = { [weak self] transferData, wallet throws(TransactionConfirmationError) in
            guard let self else {
                throw .cancelledByUser
            }
            return try await signTransactions(
                transferData: transferData,
                wallet: wallet
            )
        }

        update(with: confirmationController.getModel())

        update()
    }

    func viewDidAppear() {}

    func viewDidDisappear() {}

    func didTapCloseButton() {
        didClose?()
    }

    private func update() {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            guard let self else { return }

            state = .idle
            confirmationController.setLoading()
            let loadingModel = confirmationController.getModel()
            update(with: loadingModel)

            let redSession = RedAnalyticsSessionHolder(
                analytics: analyticsProvider
            )
            redSession.start(
                flow: .swap,
                operation: .emulate,
                attemptSource: .nativeUI,
                otherMetadata: redMetadata(
                    feePaidIn: nil,
                    includeAmounts: true
                )
            )
            let result = await self.confirmationController.emulate()
            guard !Task.isCancelled else {
                return redSession.finish(
                    outcome: .cancel,
                    stage: "emulate"
                )
            }
            switch result {
            case .success:
                redSession.finish(
                    outcome: .success,
                    stage: "emulate"
                )
            case let .failure(error):
                redSession.finish(
                    outcome: .fail,
                    error: error,
                    stage: "emulate"
                )
                handleError(error)
            }

            let model = confirmationController.getModel()
            update(with: model)

            do {
                try await fundsValidator.validateFundsIfNeeded(
                    wallet: model.wallet,
                    emulationModel: model
                )
            } catch {
                guard !Task.isCancelled else { return }

                if let error = error as? InsufficientFundsError {
                    didProduceInsufficientFundsError?(error)
                }
            }
        }
    }

    @MainActor
    private func update(with transaction: TransactionConfirmationModel) {
        let items: [TKPopUp.Item] = [
            TKPopUp.Component.GroupComponent(
                padding: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16),
                items: [
                    makeContentItem(transaction: transaction),
                ]
            ),
        ]

        let bottomItems: [TKPopUp.Item] = [
            makeActionBar(transaction: transaction),
        ]

        let configuration = TKPopUp.Configuration(
            items: items,
            bottomItems: bottomItems
        )

        didUpdateConfiguration?(configuration)
    }

    func makeContentItem(transaction: TransactionConfirmationModel) -> TKPopUp.Item {
        var extraType: TransactionConfirmationModel.ExtraType = .default

        switch transaction.extraState {
        case .loading:
            break
        case let .extra(extra):
            switch extra.value {
            case .battery:
                extraType = .battery
            case .default:
                extraType = .default
            case let .gasless(token, _):
                extraType = .gasless(token: token)
            case let .multichain(token, _):
                extraType = .multichain(token: token)
            }
        case .none:
            break
        }

        let feeValueFormatted = formatApproximateValue(
            formatExtraAmount(
                model.confirmation.estimatedGasConsumption,
                extraType: extraType
            )
        )
        let reserveValue = formatExtraAmount(
            model.confirmation.gasBudget,
            extraType: extraType
        )
        let reserveValueFormatted = formatApproximateValue(reserveValue)

        let tradeStartDeadline: Date? = {
            guard let timestamp = Double(model.confirmation.tradeStartDeadline) else { return nil }

            let date: Date
            if timestamp > 1_000_000_000_000 {
                date = Date(timeIntervalSince1970: timestamp / 1000)
            } else {
                date = Date(timeIntervalSince1970: timestamp)
            }

            return date
        }()

        let reserveInfoAction: (UIView) -> Void = { [weak self] sourceView in
            switch extraType {
            case .battery:
                self?.didRequestBatteryTemporaryReserveInfo?(reserveValue, sourceView)
            case .default, .gasless, .multichain:
                self?.didRequestTemporaryReserveInfo?(reserveValue, sourceView)
            }
        }

        let valueDifferenceConfiguration: NativeSwapTransactionConfirmationContainerView.Configuration.Item? = {
            guard let percentage = getValueDifferencePercentage() else { return nil }
            let zone = ValueDifferenceZone(percentage: percentage)
            return NativeSwapTransactionConfirmationContainerView.Configuration.Item(
                title: TKLocales.NativeSwap.Screen.Confirm.Field.valueDifference,
                value: getValueDifferenceFormattedValue(percentage: percentage),
                valueColor: getValueDifferenceValueColor(zone: zone),
                valueIcon: getValueDifferenceIcon(zone: zone)
            )
        }()

        let configuration = NativeSwapTransactionConfirmationContainerView
            .Configuration(
                sendAmount: model.sendFormatted,
                receiveAmount: model.receiveFormatted,
                didAvailableExtraTypes: transaction.availableExtraTypes.count > 1,
                rate: NativeSwapTransactionConfirmationContainerView
                    .Configuration.Item(
                        title: TKLocales.NativeSwap.Screen.Confirm.Field.rate,
                        value: model.rateFormatted
                    ),

                fee: NativeSwapTransactionConfirmationContainerView
                    .Configuration.Item(
                        title: TKLocales.NativeSwap.Screen.Confirm.Field.fee,
                        value: feeValueFormatted
                    ),
                reserve: NativeSwapTransactionConfirmationContainerView
                    .Configuration.Item(
                        title: TKLocales.NativeSwap.Screen.Confirm.Field.temporaryReserve,
                        value: reserveValueFormatted
                    ),

                provider: NativeSwapTransactionConfirmationContainerView
                    .Configuration.Item(
                        title: TKLocales.NativeSwap.Screen.Confirm.Field.provider,
                        value: model.confirmation.resolverName
                    ),
                slippage: NativeSwapTransactionConfirmationContainerView
                    .Configuration.Item(
                        title: TKLocales.NativeSwap.Screen.Confirm.Field.slippage,
                        value: String(format: "%g%%", Double(model.confirmation.slippage) / 100)
                    ),
                valueDifference: valueDifferenceConfiguration,
                didTapEdit: { [weak self] isSend in
                    self?.didTapPop?()
                    self?.didTapEdit?(isSend)
                },
                didTapFeeType: { [weak self] sourceView in
                    guard transaction.availableExtraTypes.count > 1,
                          let self else { return }

                    let items = transaction.availableExtraTypes.map { extraType in
                        let title = switch extraType {
                        case .default: TKLocales.ExtraType.ton
                        case .battery: TKLocales.ExtraType.battery
                        case let .gasless(token): token.symbol ?? token.name
                        case let .multichain(token): token.symbol
                        }

                        let leftIcon = switch extraType {
                        case .default:
                            TKImageView.Model(
                                image: .image(.TKUIKit.Icons.Size44.tonLogo),
                                tintColor: nil,
                                corners: .circle
                            )
                        case .battery:
                            TKImageView.Model(
                                image: .image(.TKUIKit.Icons.Size24.flash),
                                tintColor: .Accent.green,
                                corners: .none
                            )
                        case let .gasless(token):
                            TKImageView.Model(
                                image: .urlImage(token.imageURL),
                                tintColor: nil,
                                corners: .circle
                            )
                        case let .multichain(token):
                            TKImageView.Model(
                                image: AssetIdResolver.tkImageSource(
                                    for: token.assetId,
                                    imageUrl: URL(string: token.image),
                                    multichainEnabled: true
                                ).image,
                                tintColor: nil,
                                corners: .circle
                            )
                        }

                        return TKPopupMenuItem(
                            title: title,
                            value: nil,
                            description: nil,
                            icon: nil,
                            leftIcon: leftIcon
                        ) { [weak self] in
                            guard let self else { return }

                            confirmationController.setPrefferedExtraType(extraType: extraType)
                            update()
                        }
                    }

                    let selectedIndex = transaction.availableExtraTypes.firstIndex(of: extraType)

                    TKPopupMenuController.show(
                        sourceView: sourceView,
                        position: .bottomRight(inset: 8),
                        minimumWidth: 0,
                        items: items,
                        selectedIndex: selectedIndex
                    )
                },
                didTapSlippageInfo: { [weak self] sourceView in
                    guard let self else { return }
                    self.didRequestSlippageInfo?(sourceView)
                },
                didTapValueDifferenceInfo: valueDifferenceConfiguration != nil
                    ? { [weak self] sourceView in
                        guard let self else { return }
                        self.didRequestValueDifferenceInfo?(sourceView)
                    }
                    : nil,
                didTapReserveInfo: reserveInfoAction,
                tradeStartDeadline: tradeStartDeadline,
                didTimerFinished: { [weak self] in
                    self?.didTapPop?()
                    self?.didTapEdit?(nil)
                }
            )

        return NativeSwapTransactionConfirmationContainerPopUpItem(
            configuration: configuration,
            bottomSpace: 0
        )
    }

    private func makeActionBar(transaction: TransactionConfirmationModel) -> TKPopUp.Item {
        var items: [TKPopUp.Item] = []

        items.append(makeConfirmSlider(transaction: transaction))

        let itemState: TKProcessContainerView.State = {
            switch state {
            case .idle: .idle
            case .processing: .process
            case .success: .success
            case .failed: .failed
            }
        }()

        return TKPopUp.Component.Process(
            items: items,
            state: itemState,
            successTitle: TKLocales.Result.success,
            errorTitle: TKLocales.Result.failure,
            bottomSpace: 0
        )
    }

    private func makeConfirmSlider(transaction: TransactionConfirmationModel) -> TKPopUp.Item {
        let title = NSMutableAttributedString()
        title.append(
            TKLocales.Actions.Confirm.title.withTextStyle(
                .label2,
                color: .Text.secondary,
                alignment: .center
            )
        )
        title.append(
            ("\n" + TKLocales.Actions.Confirm.subtitle).withTextStyle(
                .body3,
                color: .Text.tertiary,
                alignment: .center
            )
        )

        let sliderItem = NativeSwapTransactionConfirmationActionPopUpItem(
            configuration: NativeSwapTransactionConfirmationActionView.Configuration(
                slider: NativeSwapTransactionConfirmationActionView.Configuration.Slider(
                    title: title,
                    isEnable: true,
                    appearance: .standart,
                    didConfirm: { [weak self] in
                        self?.confirmAction(transaction: transaction)
                    }
                )
            ),
            bottomSpace: 0
        )

        return TKPopUp.Component.GroupComponent(
            padding: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16),
            items: [
                sliderItem,
            ]
        )
    }

    private func confirmAction(transaction: TransactionConfirmationModel) {
        confirmTask?.cancel()
        confirmTask = Task { [weak self] in
            guard let self else { return }

            let redSession = RedAnalyticsSessionHolder(
                analytics: analyticsProvider
            )
            redSession.start(
                flow: .swap,
                operation: .send,
                attemptSource: .nativeUI,
                otherMetadata: redMetadata(
                    feePaidIn: getFeePaidIn(transaction: transaction),
                    includeAmounts: true
                )
            )
            state = .processing
            let result = await runConfirmAction(
                transaction: transaction
            )
            switch result {
            case .cancelledByUser:
                redSession.finish(
                    outcome: .cancel,
                    stage: "confirm"
                )
                state = .idle
            case let .insufficientFunds(error):
                redSession.finish(
                    outcome: .fail,
                    error: error,
                    stage: "send"
                )
                state = .failed
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                state = .idle
                didProduceInsufficientFundsError?(error)
            case let .sendFailed(error):
                redSession.finish(
                    outcome: .fail,
                    error: error,
                    stage: "send"
                )
                analyticsProvider.log(
                    event: .NativeSwap.failed(
                        from: model.fromToken.analyticsSymbol,
                        to: model.toToken.analyticsSymbol,
                        feeProvider: getFeePaidIn(transaction: transaction),
                        error: error
                    ),
                    utm: model.utm
                )
                state = .failed
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                state = .idle
                if let tonSwapInsufficientFeeData = tonSwapInsufficientFeeData(
                    transaction: transaction,
                    error: error
                ) {
                    didProduceTonSwapInsufficientFeeError?(
                        tonSwapInsufficientFeeData.requiredFee,
                        tonSwapInsufficientFeeData.balance
                    )
                } else {
                    handleError(error)
                }
            case .success:
                redSession.finish(
                    outcome: .success,
                    stage: "send"
                )
                state = .success
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                NotificationCenter.default.postTransactionSendNotification(
                    wallet: wallet,
                    patch: model.transactionSentNotificationPatch
                )
                didConfirmTransaction?()
                analyticsProvider.log(
                    event: .NativeSwap.success(
                        from: model.fromToken.analyticsSymbol,
                        to: model.toToken.analyticsSymbol,
                        feeProvider: getFeePaidIn(transaction: transaction)
                    ),
                    utm: model.utm
                )
                analyticsProvider.logSwapCompleted()
            }
        }
    }

    private func runConfirmAction(
        transaction: TransactionConfirmationModel
    ) async -> ConfirmActionResult {
        if transaction.isMaxAmountUsed {
            let tokenName = transaction.amount?.token.symbol ?? "Token"
            let confirmed = await withCheckedContinuation { continuation in
                didRequestSendAllConfirmation?(tokenName) { confirmed in
                    continuation.resume(returning: confirmed)
                }
            }
            guard confirmed else {
                return .cancelledByUser
            }
        }
        analyticsProvider.log(
            event: .NativeSwap.confirm(
                from: model.fromToken.analyticsSymbol,
                to: model.toToken.analyticsSymbol,
                feeProvider: getFeePaidIn(transaction: transaction)
            ),
            utm: model.utm
        )
        do {
            try await self.fundsValidator.validateFundsIfNeeded(
                wallet: self.wallet,
                emulationModel: transaction
            )
        } catch {
            return .insufficientFunds(error)
        }
        let result = await self.confirmationController.sendTransaction()

        switch result {
        case let .success(sendResult):
            await pendingTransactionsService.record(sendResult, wallet: self.wallet)
            return .success
        case let .failure(error):
            if case .cancelledByUser = error {
                return .cancelledByUser
            }
            return .sendFailed(error)
        }
    }

    private func handleError(_ error: TransactionConfirmationError) {
        let text: String
        switch error {
        case .failedToCalculateFee:
            text = "Failed to calculate fee"
        case let .failedToSendTransaction(message):
            text = message ?? "Failed to send transaction"
        case let .multichainTransactionFailure(failure):
            text = failure.transactionConfirmationUserMessage
        case .failedToSign:
            text = "Failed to sign"
        case .cancelledByUser:
            text = "Cancelled"
        }

        ToastPresenter.showToast(configuration: .defaultConfiguration(text: text))
    }

    private func tonSwapInsufficientFeeData(
        transaction: TransactionConfirmationModel,
        error: TransactionConfirmationError
    ) -> (requiredFee: BigUInt, balance: BigUInt)? {
        guard case .ton(.ton) = model.fromToken else {
            return nil
        }
        guard case .failedToSendTransaction = error else {
            return nil
        }

        let requiredFee = model.confirmation.requiredGasAmount
        let balance = sendController.getMaximumAmount(token: .ton)
        let transferAmount = transaction.amount?.value ?? model.fromAmount

        guard transferAmount + requiredFee > balance else {
            return nil
        }

        return (
            requiredFee: requiredFee,
            balance: balance
        )
    }

    private func getExchangeRateForOneToken() -> String {
        let fromAmount = BigUInt(model.confirmation.bidUnits) ?? 0
        let toAmount = BigUInt(model.confirmation.askUnits) ?? 0

        guard fromAmount > 0, toAmount > 0 else { return "" }

        let fromSymbol = model.fromToken.symbol
        let toSymbol = getToTokenSymbol()

        let fromDecimalNumber = NSDecimalNumber.fromBigUInt(
            value: fromAmount,
            decimals: model.fromToken.fractionDigits
        )
        let toDecimalNumber = NSDecimalNumber.fromBigUInt(
            value: toAmount,
            decimals: model.toToken.fractionDigits
        )

        let rateDecimal = toDecimalNumber.dividing(by: fromDecimalNumber)
        let rateMultiplied = rateDecimal.multiplying(byPowerOf10: Int16(model.toToken.fractionDigits))
        let roundedRate = rateMultiplied.rounding(accordingToBehavior: NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        ))

        let formattedRate = amountFormatter.format(
            amount: BigUInt(roundedRate.stringValue) ?? 0,
            fractionDigits: model.toToken.fractionDigits
        )

        return "1 \(fromSymbol) \(TKLocales.Common.Numbers.approximate) \(formattedRate) \(toSymbol)"
    }

    private func getToTokenSymbol() -> String {
        switch model.toToken {
        case let .ton(token):
            token.symbol
        case .tron:
            model.toToken.symbol + " TRC20"
        }
    }

    private func getFeePaidIn(transaction: TransactionConfirmationModel) -> String {
        switch transaction.extraState {
        case let .extra(extra):
            switch extra.value {
            case .battery:
                return "battery"
            case .default:
                return "ton"
            case .gasless:
                return "ton"
            case let .multichain(token, _):
                return token.symbol
            }

        default:
            return "unknown"
        }
    }

    private func getValueDifferencePercentage() -> Decimal? {
        if let valueDifferenceBps = model.confirmation.valueDifferenceBps {
            return Decimal(valueDifferenceBps) / 100
        }

        return nil
    }

    private func formatTonAmount(_ amountString: String) -> String {
        guard let amount = BigUInt(amountString) else { return "-" }

        return amountFormatter.format(
            amount: amount,
            fractionDigits: TonInfo.fractionDigits,
            accessory: .tokenSymbol(TonInfo.symbol)
        )
    }

    private func formatExtraAmount(
        _ amountString: String,
        extraType: TransactionConfirmationModel.ExtraType
    ) -> String {
        switch extraType {
        case .battery:
            return formatBatteryCharges(amountString)
        case .default, .gasless, .multichain:
            return formatTonAmount(amountString)
        }
    }

    private func formatBatteryCharges(_ amountString: String) -> String {
        guard let amount = BigUInt(amountString) else { return "-" }

        let tonAmount = NSDecimalNumber.fromBigUInt(
            value: amount,
            decimals: TonInfo.fractionDigits
        )
        guard let charges = batteryCalculation.calculateCharges(tonAmount: tonAmount) else {
            return "-"
        }

        return "\(charges) \(TKLocales.Battery.Refill.chargesCount(count: charges))"
    }

    private func formatApproximateValue(_ value: String) -> String {
        guard value != "-" else { return value }

        return "\(TKLocales.Common.Numbers.approximate) \(value)"
    }

    private func getValueDifferenceFormattedValue(percentage: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2

        let number = NSDecimalNumber(decimal: percentage)
        let formatted = formatter.string(from: number) ?? number.stringValue

        return "\(formatted)%"
    }

    private func getValueDifferenceValueColor(zone: ValueDifferenceZone) -> UIColor {
        switch zone {
        case .normal: return .Text.primary
        case .yellow: return .Accent.orange
        case .red: return .Accent.red
        }
    }

    private func getValueDifferenceIcon(zone: ValueDifferenceZone) -> UIImage? {
        switch zone {
        case .normal: return nil
        case .yellow: return .TKUIKit.Icons.Size16.exclamationMarkCircle
        case .red: return .TKUIKit.Icons.Size16.exclamationmarkTriangle
        }
    }

    private func redMetadata(
        feePaidIn: String?,
        includeAmounts: Bool
    ) -> RedAnalyticsMetadata? {
        [
            "from_token": model.fromToken.analyticsSymbol,
            "to_token": model.toToken.analyticsSymbol,
            .feePaidIn: feePaidIn,
            "from_amount": includeAmounts
                ? NSDecimalNumber.fromBigUInt(
                    value: model.fromAmount,
                    decimals: model.fromToken.fractionDigits
                ).doubleValue
                : nil,
            "to_amount": includeAmounts
                ? NSDecimalNumber.fromBigUInt(
                    value: model.toAmount,
                    decimals: model.toToken.fractionDigits
                ).doubleValue
                : nil,
        ]
    }

    private func signTransactions(
        transferData: TransferData,
        wallet: Wallet
    ) async throws(TransactionConfirmationError) -> SignedTransactions {
        guard let didRequireSign else {
            throw .cancelledByUser
        }
        let transactions: SignedTransactions
        do {
            transactions = try await didRequireSign(transferData, wallet)
        } catch {
            switch error {
            case .cancelled:
                throw .cancelledByUser
            default:
                throw .failedToSign(
                    message: "wallet transfer sign error: \(error.localizedDescription)"
                )
            }
        }
        return transactions
    }
}

private extension NativeSwapTransactionConfirmationViewModelImplementation {
    enum ConfirmActionResult {
        case cancelledByUser
        case insufficientFunds(InsufficientFundsError)
        case sendFailed(TransactionConfirmationError)
        case success
    }

    enum ValueDifferenceZone {
        case normal
        case yellow
        case red

        init(percentage: Decimal) {
            if percentage < -5 {
                self = .red
            } else if percentage < -3 {
                self = .yellow
            } else {
                self = .normal
            }
        }
    }
}
