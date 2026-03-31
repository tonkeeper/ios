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
}

@MainActor
protocol NativeSwapTransactionConfirmationViewModel: AnyObject {
    var didTapPop: (() -> Void)? { get set }
    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }
    var didRequestSendAllConfirmation: ((String, @escaping (Bool) -> Void) -> Void)? { get set }
    var didRequestSlippageInfo: (() -> Void)? { get set }

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
    var didRequestSlippageInfo: (() -> Void)?
    var didProduceInsufficientFundsError: ((InsufficientFundsError) -> Void)?

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
    private let sendController: SendV3Controller
    private let amountFormatter: AmountFormatter
    private let fundsValidator: InsufficientFundsValidator
    private let currencyStore: CurrencyStore
    private let ratesService: RatesService
    private let nativeSwapService: NativeSwapService
    private let configurationAssembly: ConfigurationAssembly
    private let configuration: Configuration
    private let analyticsProvider: AnalyticsProvider

    private var model: NativeSwapTransactionConfirmationModel

    private var updateTask: Task<Void, Never>?
    private var fetchConfirmationTask: Task<Void, Error>?
    private var updateTimer: DispatchSourceTimer?
    private var confirmTask: Task<Void, Never>?

    init(
        wallet: Wallet,
        sendController: SendV3Controller,
        confirmationController: TransactionConfirmationController,
        model: NativeSwapTransactionConfirmationModel,
        amountFormatter: AmountFormatter,
        fundsValidator: InsufficientFundsValidator,
        currencyStore: CurrencyStore,
        ratesService: RatesService,
        nativeSwapService: NativeSwapService,
        configurationAssembly: ConfigurationAssembly,
        configuration: Configuration,
        analyticsProvider: AnalyticsProvider
    ) {
        self.wallet = wallet
        self.sendController = sendController
        self.confirmationController = confirmationController
        self.model = model
        self.amountFormatter = amountFormatter
        self.fundsValidator = fundsValidator
        self.currencyStore = currencyStore
        self.ratesService = ratesService
        self.nativeSwapService = nativeSwapService
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
                analytics: analyticsProvider,
                configurationAssembly: configurationAssembly
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
        let approximateSymbol = TKLocales.Common.Numbers.approximate
        var extraType: TransactionConfirmationModel.ExtraType = .default
        var feeValueFormatted = ""

        switch transaction.extraState {
        case .loading:
            break
        case let .extra(extra):
            switch extra.value {
            case let .battery(charges, _):
                if let charges {
                    extraType = .battery
                    feeValueFormatted = "\(charges) \(TKLocales.Battery.Refill.chargesCount(count: charges))"
                }
            case let .default(amount):
                extraType = .default
                feeValueFormatted = amountFormatter.format(
                    amount: amount,
                    fractionDigits: TonInfo.fractionDigits,
                    accessory: .symbol(TonInfo.symbol)
                )
            case let .gasless(token, amount):
                extraType = .gasless(token: token)
                feeValueFormatted = amountFormatter.format(
                    amount: amount,
                    fractionDigits: token.fractionDigits,
                    accessory: .symbol(token.symbol ?? token.name)
                )
            }
        case .none:
            feeValueFormatted = "-"
        }

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
                        value: "\(approximateSymbol) \(feeValueFormatted)"
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
                        }

                        let leftIcon = switch extraType {
                        case .default:
                            TKImageView.Model(
                                image: .image(.TKCore.Icons.Size44.tonLogo),
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
                        width: 0,
                        items: items,
                        selectedIndex: selectedIndex
                    )
                },
                didTapSlippageInfo: { [weak self] in
                    guard let self else { return }
                    self.didRequestSlippageInfo?()
                },
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
                analytics: analyticsProvider,
                configurationAssembly: configurationAssembly
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
                handleError(error)
                analyticsProvider.log(event: .NativeSwap.failed(
                    from: model.fromToken.analyticsSymbol,
                    to: model.toToken.analyticsSymbol,
                    feeProvider: getFeePaidIn(transaction: transaction),
                    error: error
                ))
                state = .failed
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                state = .idle
            case .success:
                redSession.finish(
                    outcome: .success,
                    stage: "send"
                )
                state = .success
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                NotificationCenter.default.postTransactionSendNotification(wallet: wallet)
                didConfirmTransaction?()
                analyticsProvider.log(
                    event: .NativeSwap.success(
                        from: model.fromToken.analyticsSymbol,
                        to: model.toToken.analyticsSymbol,
                        feeProvider: getFeePaidIn(transaction: transaction)
                    )
                )
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
        analyticsProvider.log(event: .NativeSwap.confirm(
            from: model.fromToken.analyticsSymbol,
            to: model.toToken.analyticsSymbol,
            feeProvider: getFeePaidIn(transaction: transaction)
        ))
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
        case .success:
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
        case .failedToSign:
            text = "Failed to sign"
        case .cancelledByUser:
            text = "Cancelled"
        }

        ToastPresenter.showToast(configuration: .defaultConfiguration(text: text))
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
            }

        default:
            return "unknown"
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
}
