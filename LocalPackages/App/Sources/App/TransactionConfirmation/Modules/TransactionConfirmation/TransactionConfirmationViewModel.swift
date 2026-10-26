import AppUI
import BigInt
import KeeperCore
import SwiftUI
import TKFeatureFlags
import TKLocalize
import TKUIKit
import TronSwift
import UIKit

struct WithdrawDisplayInfo {
    let fromSymbol: String
    let fromImageUrl: String?
    let fromNetworkName: String
    let fromNetworkType: String
    let symbol: String
    let imageUrl: String?
    let networkName: String
    let networkType: String
    let estimatedDurationSeconds: Int?
    let withdrawalFeeUsd: Double?
}

@MainActor
protocol TransactionConfirmationOutput: AnyObject {
    var didRequireSign: ((TransferData, Wallet) async throws(WalletTransferSignError) -> SignedTransactions)? { get set }
    var didStartEmulation: (() -> Void)? { get set }
    var didFinishEmulation: ((TransactionConfirmationError?) -> Void)? { get set }
    var didCancelEmulation: (() -> Void)? { get set }
    var didOpenFeePicker: ((NetworkFeePickerPresentation) -> Void)? { get set }
    var didStartConfirmTransaction: ((TransactionConfirmationModel) -> Void)? { get set }
    var didConfirmTransaction: ((TransactionConfirmationModel) -> Void)? { get set }
    var didFailTransaction: ((TransactionConfirmationModel, any AnalyticsError) -> Void)? { get set }
    var didCancelTransaction: (() -> Void)? { get set }
    var didProduceInsufficientFundsError: ((_ error: InsufficientFundsError) -> Void)? { get set }
    var didRequestOpenFeeRefill: ((_ extraType: TransactionConfirmationModel.ExtraType) -> Void)? { get set }
    var didDetectInsufficientMultichainFee: ((MultichainNativeFeeShortage) -> Void)? { get set }
    var didDetectInsufficientTronFee: ((TronFeeShortage) -> Void)? { get set }
    var didClose: (() -> Void)? { get set }

    func refresh()
}

@MainActor
protocol TransactionConfirmationViewModel: AnyObject {
    var didUpdateState: ((ConfirmActionState) -> Void)? { get set }
    var didRequestSendAllConfirmation: ((String, @escaping (Bool) -> Void) -> Void)? { get set }
    func viewDidLoad()
    func didTapCloseButton()
}

@MainActor
final class TransactionConfirmationViewModelImplementation: TransactionConfirmationViewModel, TransactionConfirmationOutput {
    // MARK: - TransactionConfirmationOutput

    var didRequireSign: ((TransferData, Wallet) async throws(WalletTransferSignError) -> SignedTransactions)?
    var didStartEmulation: (() -> Void)?
    var didFinishEmulation: ((TransactionConfirmationError?) -> Void)?
    var didCancelEmulation: (() -> Void)?
    var didOpenFeePicker: ((NetworkFeePickerPresentation) -> Void)?
    var didStartConfirmTransaction: ((TransactionConfirmationModel) -> Void)?
    var didConfirmTransaction: ((TransactionConfirmationModel) -> Void)?
    var didFailTransaction: ((TransactionConfirmationModel, any AnalyticsError) -> Void)?
    var didCancelTransaction: (() -> Void)?
    var didProduceInsufficientFundsError: ((_ error: InsufficientFundsError) -> Void)?
    var didRequestOpenFeeRefill: ((_ extraType: TransactionConfirmationModel.ExtraType) -> Void)?
    var didDetectInsufficientMultichainFee: ((MultichainNativeFeeShortage) -> Void)?
    var didDetectInsufficientTronFee: ((TronFeeShortage) -> Void)?
    var didClose: (() -> Void)?
    var didRequestSendAllConfirmation: ((String, @escaping (Bool) -> Void) -> Void)?

    // MARK: - TransactionConfirmationViewModel

    var didUpdateState: ((ConfirmActionState) -> Void)?

    func viewDidLoad() {
        confirmationController.signHandler = { [weak self] transferData, wallet throws(TransactionConfirmationError) in
            guard let self else {
                throw .cancelledByUser
            }
            return try await signTransactions(
                transferData: transferData,
                wallet: wallet
            )
        }

        state = .processing
        update()
    }

    func didTapCloseButton() {
        updateTask?.cancel()
        confirmTask?.cancel()
        didClose?()
    }

    func refresh() {
        update()
    }

    // MARK: - State

    private var state: ConfirmActionBarState.Process = .idle {
        didSet {
            let model = confirmationController.getModel()
            update(with: model)
        }
    }

    /// A declined send-all confirmation leaves `process` at `.idle` throughout, so the slider needs
    /// an explicit nudge to spring back from its swiped position.
    private var sliderResetToken = 0
    /// Set once a relayer may have broadcast the transfer: from then on the screen offers no second send.
    private var isRetryUnsafe = false

    private var hasUserSelectedFeeMethod = false

    private var amountRate: Rates.Rate?
    private var feeRate: Rates.Rate?
    private var tonRate: Rates.Rate?
    private var trxRate: Rates.Rate?
    private var usdtFiatRate: Rates.Rate?
    private var walletBalance: KeeperCore.WalletBalance?

    private var updateTask: Task<Void, Never>?
    private var confirmTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let confirmationController: TransactionConfirmationController
    private let pendingTransactionsService: PendingTransactionsService
    private let amountFormatter: AmountFormatter
    private let fundsValidator: InsufficientFundsValidator
    private let currencyStore: CurrencyStore
    private let ratesService: RatesService
    private let balanceService: BalanceService
    private let multichainAssetBalanceProvider: MultichainAssetBalanceProvider
    private let batteryCalculation: BatteryCalculation
    private let feeCalculator: TransactionConfirmationFeeCalculator
    private let textFormatter: TransactionConfirmationTextFormatter
    private let configurationAssembly: ConfigurationAssembly
    private let transactionSentNotificationPatch: (inout [String: Any]) -> Void
    private let withdrawDisplayInfo: WithdrawDisplayInfo?

    // MARK: - Init

    init(
        confirmationController: TransactionConfirmationController,
        pendingTransactionsService: PendingTransactionsService,
        amountFormatter: AmountFormatter,
        fundsValidator: InsufficientFundsValidator,
        currencyStore: CurrencyStore,
        ratesService: RatesService,
        balanceService: BalanceService,
        multichainAssetBalanceProvider: MultichainAssetBalanceProvider,
        batteryCalculation: BatteryCalculation,
        configurationAssembly: ConfigurationAssembly,
        transactionSentNotificationPatch: @escaping (inout [String: Any]) -> Void = { _ in },
        withdrawDisplayInfo: WithdrawDisplayInfo? = nil
    ) {
        self.confirmationController = confirmationController
        self.pendingTransactionsService = pendingTransactionsService
        self.amountFormatter = amountFormatter
        self.fundsValidator = fundsValidator
        self.currencyStore = currencyStore
        self.ratesService = ratesService
        self.balanceService = balanceService
        self.multichainAssetBalanceProvider = multichainAssetBalanceProvider
        self.configurationAssembly = configurationAssembly
        self.batteryCalculation = batteryCalculation
        self.transactionSentNotificationPatch = transactionSentNotificationPatch
        self.withdrawDisplayInfo = withdrawDisplayInfo
        feeCalculator = TransactionConfirmationFeeCalculator(
            configuration: configurationAssembly.configuration
        )
        textFormatter = TransactionConfirmationTextFormatter(
            amountFormatter: amountFormatter
        )
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

    // MARK: - Private

    private func update() {
        guard !isRetryUnsafe else {
            return
        }
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            guard let self else { return }
            defer { updateTask = nil }

            state = .idle
            confirmationController.setLoading()
            let loadingModel = confirmationController.getModel()
            update(with: loadingModel)
            didStartEmulation?()
            let didCancelEmulation = self.didCancelEmulation
            // TODO: сбрасывать текущий стейт, чтобы комиссия была со скелетоном
            let result = await withTaskCancellationHandler(
                operation: {
                    await self.confirmationController.emulate()
                },
                onCancel: {
                    didCancelEmulation?()
                }
            )
            guard !Task.isCancelled else { return }
            if case let .failure(error) = result {
                didFinishEmulation?(error)
                handleError(error)
            } else {
                didFinishEmulation?(nil)
            }
            var model = confirmationController.getModel()
            reportInsufficientMultichainFeeIfNeeded(model)
            let currency = currencyStore.state
            // Before the rates: the fee method chosen from these balances decides the fee's rate.
            self.walletBalance = await loadWalletBalance(
                wallet: model.wallet,
                currency: currency
            )
            guard !Task.isCancelled else { return }
            if preselectPayableTronFeeIfNeeded(model) {
                model = confirmationController.getModel()
            }
            let rates = await getRates(model: model, currency: currency)
            guard !Task.isCancelled else { return }
            self.amountRate = rates.valueRate
            self.feeRate = rates.feeRate
            self.tonRate = rates.tonRate
            self.trxRate = rates.trxRate
            self.usdtFiatRate = rates.usdtFiatRate
            update(with: model)
            reportInsufficientTronFeeIfNeeded(model)

            do {
                try await fundsValidator.validateFundsIfNeeded(wallet: model.wallet, emulationModel: model)
            } catch {
                guard !Task.isCancelled else { return }
                if let error = error as? InsufficientFundsError {
                    didProduceInsufficientFundsError?(error)
                }
            }
        }
    }

    @MainActor
    private func update(with model: TransactionConfirmationModel) {
        let currency = currencyStore.state
        let showsTitle = withdrawDisplayInfo == nil
        didUpdateState?(ConfirmActionState(
            header: header(transaction: model),
            caption: showsTitle ? caption(transaction: model.transaction) : nil,
            title: showsTitle ? actionName(transaction: model.transaction) : nil,
            titleSuffix: showsTitle ? titleSuffix(transaction: model.transaction) : nil,
            rows: rows(transaction: model, currency: currency),
            footer: showsTitle ? nil : AnyView(TransactionConfirmationDisclaimerView(model: .changelly)),
            action: actionBar(model: model)
        ))
    }

    private func reportInsufficientMultichainFeeIfNeeded(_ model: TransactionConfirmationModel) {
        guard let shortage = model.nativeFeeShortage else {
            return
        }
        didDetectInsufficientMultichainFee?(shortage)
    }

    private func caption(transaction: TransactionConfirmationModel.Transaction) -> String {
        guard case let .transfer(.nft(nft)) = transaction else {
            return TKLocales.TransactionConfirmation.confirmAction
        }
        var result = nft.notNilName
        if let collectionName = nft.collection?.notEmptyName {
            result += " · "
            result += collectionName
        }
        return result
    }

    private func actionName(transaction: TransactionConfirmationModel.Transaction) -> String {
        switch transaction {
        case let .staking(staking):
            switch staking.flow {
            case .withdraw:
                TKLocales.TransactionConfirmation.unstake
            case .deposit:
                TKLocales.TransactionConfirmation.deposit
            }
        case let .transfer(transfer):
            switch transfer {
            case let .jetton(jettonInfo):
                "\(jettonInfo.symbol ?? jettonInfo.name) transfer"
            case .ton:
                "\(TonInfo.symbol) transfer"
            case .nft:
                "NFT transfer"
            case .tronUSDT:
                "Transfer \(TronSwift.USDT.name)"
            case .tronTRX:
                "Transfer \(TronSwift.TRX.name)"
            case let .multichain(asset):
                "Transfer \(asset.asset.symbol)"
            }
        }
    }

    private func titleSuffix(transaction: TransactionConfirmationModel.Transaction) -> String? {
        guard case let .transfer(.multichain(asset)) = transaction, !asset.isNative else { return nil }
        return asset.asset.chain?.shortDisplayTitle
    }

    private func header(transaction: TransactionConfirmationModel) -> ConfirmActionState.Header {
        if let info = withdrawDisplayInfo {
            let fromNetwork = RampItemConfigurator.networkLabel(network: info.fromNetworkType, networkName: info.fromNetworkName)
            let toNetwork = RampItemConfigurator.networkLabel(network: info.networkType, networkName: info.networkName)
            let exchangeModel = SendAssetExchangeView.Model(
                fromImageUrl: info.fromImageUrl.flatMap { URL(string: $0) },
                fromCode: info.fromSymbol,
                fromNetwork: fromNetwork,
                toCode: info.symbol,
                toNetwork: toNetwork,
                toImageUrl: info.imageUrl.flatMap { URL(string: $0) },
                rate: .empty,
                subtitle: TKLocales.TransactionConfirmation.confirmAction
            )
            return .custom(AnyView(TransactionConfirmationExchangeHeader(model: exchangeModel)))
        }

        switch transaction.transaction {
        case let .staking(staking):
            return .avatar(.image(staking.pool.bigIcon))
        case let .transfer(transfer):
            switch transfer {
            case let .jetton(jettonInfo):
                let chainIcon: UIImage? = transaction.wallet.tron != nil && jettonInfo.isTonUSDT
                    ? .TKUIKit.Icons.Size44.tonChain
                    : nil
                return .avatar(.url(jettonInfo.imageURL, chainIcon: chainIcon))
            case .ton:
                return .avatar(.image(.TKUIKit.Icons.Size44.currencyTon))
            case let .nft(nft):
                return .avatar(.url(nft.imageURL), shape: .rectangle(cornerRadius: 12))
            case .tronUSDT:
                return .avatar(.image(.TKUIKit.Icons.Size96.currencyUsdt, chainIcon: .TKUIKit.Icons.Size44.currencyTrc20))
            case .tronTRX:
                return .avatar(.image(.TKUIKit.Icons.Size44.trxChain))
            case let .multichain(asset):
                return .avatar(AssetIdResolver.imageSource(
                    for: asset.asset.assetId,
                    imageUrl: URL(string: asset.asset.image),
                    multichainEnabled: true
                ))
            }
        }
    }

    private func rows(transaction: TransactionConfirmationModel, currency: Currency) -> [ConfirmActionRow] {
        [
            walletRow(transaction: transaction),
            recipientRow(transaction: transaction),
            recipientAddressRow(transaction: transaction),
            assetChainRow(transaction: transaction),
            networkRow(),
            amountRow(transaction: transaction, rate: amountRate, currency: currency),
            apyRow(transaction: transaction),
            withdrawalFeeRow(usdtFiatRate: usdtFiatRate, currency: currency),
            feeRow(transaction: transaction, rate: feeRate, tonRate: tonRate, trxRate: trxRate, currency: currency),
            temporaryReserveRow(transaction: transaction, rate: tonRate, currency: currency),
            withdrawalTimeRow(),
            commentRow(transaction: transaction),
        ].compactMap { $0 }
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

    private static func copyInteraction(_ value: String) -> ConfirmActionRow.Interaction {
        .tap {
            UIPasteboard.general.string = value
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            ToastPresenter.showToast(configuration: .copied)
        }
    }

    private func walletRow(transaction: TransactionConfirmationModel) -> ConfirmActionRow {
        let wallet = transaction.wallet
        let emoji: String?
        let icon: UIImage?
        switch wallet.icon {
        case let .emoji(value):
            emoji = value
            icon = nil
        case let .icon(value):
            emoji = nil
            icon = value.image
        }
        return ConfirmActionRow(
            id: "wallet",
            title: TKLocales.TransactionConfirmation.wallet,
            value: .wallet(name: wallet.label, emoji: emoji, icon: icon)
        )
    }

    private func recipientRow(transaction: TransactionConfirmationModel) -> ConfirmActionRow? {
        guard let recipient = transaction.recipient else { return nil }
        return ConfirmActionRow(
            id: "recipient",
            title: TKLocales.TransactionConfirmation.recipient,
            value: .text(recipient),
            interaction: Self.copyInteraction(recipient)
        )
    }

    private func recipientAddressRow(transaction: TransactionConfirmationModel) -> ConfirmActionRow? {
        guard let recipientAddress = transaction.recipientAddress else { return nil }
        return ConfirmActionRow(
            id: "recipientAddress",
            title: TKLocales.TransactionConfirmation.recipient,
            value: .text(recipientAddress.shortenedMiddle()),
            interaction: .hint(recipientAddress)
        )
    }

    private func assetChainRow(transaction: TransactionConfirmationModel) -> ConfirmActionRow? {
        guard case let .transfer(.multichain(asset)) = transaction.transaction,
              let chain = asset.asset.chain
        else {
            return nil
        }
        return ConfirmActionRow(
            id: "assetChain",
            title: TKLocales.Ramp.Deposit.network,
            value: .text(chain.addressConfiguration.title, subtitle: chain.tokenType)
        )
    }

    private func networkRow() -> ConfirmActionRow? {
        guard let info = withdrawDisplayInfo else { return nil }
        return ConfirmActionRow(
            id: "network",
            title: TKLocales.Ramp.Deposit.network,
            value: .text(
                info.networkName,
                subtitle: RampItemConfigurator.networkLabel(network: info.networkType, networkName: info.networkName)
            )
        )
    }

    private func withdrawalTimeRow() -> ConfirmActionRow? {
        guard let info = withdrawDisplayInfo, let seconds = info.estimatedDurationSeconds else { return nil }
        let minutes = max(1, (seconds + 59) / 60)
        return ConfirmActionRow(
            id: "withdrawalTime",
            title: TKLocales.Ramp.Withdraw.withdrawalTime,
            value: .text(TKLocales.Ramp.Deposit.upToMin(minutes))
        )
    }

    private func withdrawalFeeRow(usdtFiatRate: Rates.Rate?, currency: Currency) -> ConfirmActionRow? {
        guard let info = withdrawDisplayInfo,
              let feeUsd = info.withdrawalFeeUsd,
              feeUsd > 0
        else { return nil }

        let feeDecimal = Decimal(feeUsd)
        let topFormatted = amountFormatter.format(
            decimal: feeDecimal,
            accessory: .tokenSymbol(info.symbol, onLeft: false),
            style: .compact
        )
        let bottomFormatted: String = if let usdtFiatRate {
            amountFormatter.format(
                decimal: feeDecimal * usdtFiatRate.rate,
                accessory: .fiat(currency),
                style: .compact
            )
        } else {
            amountFormatter.format(
                decimal: feeDecimal,
                accessory: .fiat(Currency.USD),
                style: .compact
            )
        }
        return ConfirmActionRow(
            id: "withdrawalFee",
            title: TKLocales.Ramp.Withdraw.withdrawalFee,
            value: .text(
                "\(TKLocales.Common.Numbers.approximate) \(topFormatted)",
                subtitle: "\(TKLocales.Common.Numbers.approximate) \(bottomFormatted)"
            )
        )
    }

    private func commentRow(transaction: TransactionConfirmationModel) -> ConfirmActionRow? {
        guard let comment = transaction.comment, !comment.isEmpty else { return nil }
        return ConfirmActionRow(
            id: "comment",
            title: TKLocales.TransactionConfirmation.comment,
            value: .text(comment),
            interaction: Self.copyInteraction(comment)
        )
    }

    private func apyRow(transaction: TransactionConfirmationModel) -> ConfirmActionRow? {
        guard case let .staking(staking) = transaction.transaction,
              case .deposit = staking.flow else { return nil }

        let apyPercents = amountFormatter.format(
            decimal: staking.pool.apy,
            accessory: .none,
            style: .percent
        )
        return ConfirmActionRow(
            id: "apy",
            title: TKLocales.TransactionConfirmation.apy,
            value: .text("\(TKLocales.Common.Numbers.approximate) \(apyPercents)"),
            interaction: Self.copyInteraction(apyPercents)
        )
    }

    private func amountRow(
        transaction: TransactionConfirmationModel,
        rate: Rates.Rate?,
        currency: Currency
    ) -> ConfirmActionRow? {
        let title: String
        switch transaction.transaction {
        case let .staking(staking):
            switch staking.flow {
            case .withdraw:
                title = TKLocales.TransactionConfirmation.unstakeAmount
            case .deposit:
                title = TKLocales.TransactionConfirmation.amount
            }
        case let .transfer(transfer):
            switch transfer {
            case .jetton, .ton, .tronUSDT, .tronTRX, .multichain:
                title = TKLocales.TransactionConfirmation.amount
            case .nft:
                return nil
            }
        }

        guard let amount = transaction.amount else { return nil }

        let valueFormatted: String
        let convertedFormatted: String?
        if case let .multichain(asset) = amount.token {
            valueFormatted = amountFormatter.format(
                amount: amount.value,
                fractionDigits: asset.asset.decimals,
                accessory: .tokenSymbol(asset.asset.symbol),
                isNegative: false,
                style: .exactValue
            )
            convertedFormatted = multichainConvertedAmount(
                amount: amount.value,
                asset: asset,
                currency: currency
            )
        } else {
            valueFormatted = amountFormatter.format(
                amount: amount.value,
                fractionDigits: amount.token.fractionDigits,
                accessory: .tokenSymbol(amount.token.symbol),
                isNegative: false,
                style: .exactValue
            )
            convertedFormatted = rate.map { rate in
                let converted = RateConverter().convert(
                    amount: amount.value,
                    amountFractionLength: amount.token.fractionDigits,
                    rate: rate
                )
                return amountFormatter.format(
                    amount: converted.amount,
                    fractionDigits: converted.fractionLength,
                    accessory: .fiat(currency)
                )
            }
        }

        return ConfirmActionRow(
            id: "amount",
            title: title,
            value: .text(valueFormatted, subtitle: convertedFormatted),
            interaction: Self.copyInteraction(valueFormatted)
        )
    }

    private func temporaryReserveRow(
        transaction: TransactionConfirmationModel,
        rate: Rates.Rate?,
        currency: Currency
    ) -> ConfirmActionRow? {
        guard case let .staking(staking) = transaction.transaction else { return nil }
        let reserve = staking.pool.implementation.temporaryReserve
        let token = TonToken.ton
        let reserveFormatted = amountFormatter.format(
            amount: reserve,
            fractionDigits: token.fractionDigits,
            accessory: .tokenSymbol(token.symbol),
            isNegative: false,
            style: .exactValue
        )
        let convertedFormatted = rate.map { rate in
            let converted = RateConverter().convert(
                amount: reserve,
                amountFractionLength: token.fractionDigits,
                rate: rate
            )
            return amountFormatter.format(
                amount: converted.amount,
                fractionDigits: converted.fractionLength,
                accessory: .fiat(currency)
            )
        }
        let hint = switch staking.flow {
        case .withdraw:
            TKLocales.TransactionConfirmation.TemporaryReserve.unstakeHint(reserveFormatted)
        case .deposit:
            TKLocales.TransactionConfirmation.TemporaryReserve.hint(reserveFormatted)
        }
        return ConfirmActionRow(
            id: "temporaryReserve",
            title: TKLocales.TransactionConfirmation.temporaryReserve,
            value: .text(reserveFormatted, subtitle: convertedFormatted),
            titleHint: hint
        )
    }

    private func feeRow(
        transaction: TransactionConfirmationModel,
        rate: Rates.Rate?,
        tonRate: Rates.Rate?,
        trxRate: Rates.Rate?,
        currency: Currency
    ) -> ConfirmActionRow {
        var isRefund = false
        let value: ConfirmActionRow.Value
        // Open the picker when there's a choice to make, and also when the single selected method is
        // insufficient — the picker is the only path to Deposit/refill, otherwise confirm stays
        // disabled with no way to top up.
        let canOpenFeePicker = transaction.availableExtraTypes.count > 1
            || isSelectedFeeInsufficient(transaction: transaction)
        switch transaction.extraState {
        case .loading:
            value = .loading

        case let .extra(extra):
            let feeDetails = feeCalculator.feeDetails(extra: extra, wallet: transaction.wallet)
            isRefund = feeDetails.isRefund

            let feeFormatted = textFormatter.formatFeeList(
                fee: feeDetails,
                rate: rate,
                tonRate: tonRate,
                currency: currency
            )

            if canOpenFeePicker {
                let primaryText: String
                let tokenSymbol: String?
                switch feeDetails.kind {
                case .battery:
                    primaryText = "\(TKLocales.Common.Numbers.approximate) \(feeFormatted.topValue)"
                    tokenSymbol = TKLocales.TronUsdtFees.Common.ItemTitle.battery

                case let .token(_, _, symbol, _):
                    if let fiatValue = feeFormatted.bottomValue {
                        primaryText = "\(TKLocales.Common.Numbers.approximate) \(fiatValue)"
                        tokenSymbol = symbol
                    } else {
                        primaryText = "\(TKLocales.Common.Numbers.approximate) \(feeFormatted.topValue)"
                        tokenSymbol = nil
                    }
                }
                value = .feeOption(primaryText, token: tokenSymbol, showsPicker: true)
            } else {
                let tronFeeBalanceAvailability = tronFeeBalanceAvailabilityText(
                    transaction: transaction,
                    feeDetails: feeDetails
                )
                value = .text(
                    "\(TKLocales.Common.Numbers.approximate) \(feeFormatted.topValue)",
                    subtitle: tronFeeBalanceAvailability ?? feeFormatted.bottomValue
                )
            }

        case .none:
            value = .unavailable(
                TKLocales.TransactionConfirmation.feeUnavailable,
                retryTitle: TKLocales.Actions.retry,
                retry: { [weak self] in
                    self?.update()
                }
            )
        }

        let refund = isRefund
        let openPicker = { [weak self] in
            guard let self else { return }
            let presentation = makeFeePickerPresentation(
                currency: currency,
                tonRate: tonRate,
                trxRate: trxRate,
                title: refund
                    ? TKLocales.EventDetails.refund
                    : TKLocales.FeeMethodPicker.title,
                subtitle: refund
                    ? nil
                    : TKLocales.FeeMethodPicker.subtitle,
                skeletonItemCount: transaction.networkFeePickerSkeletonItemCount
            )
            didOpenFeePicker?(presentation)
        }
        // The `.unavailable` value already hosts its own Retry button; nesting a row-level tap
        // around it breaks Retry, since SwiftUI does not deliver taps to a button inside a button.
        let isFeeUnavailable = if case .none = transaction.extraState { true } else { false }
        return ConfirmActionRow(
            id: "fee",
            title: refund
                ? TKLocales.EventDetails.refund
                : feeTitle(transaction: transaction),
            value: value,
            interaction: canOpenFeePicker && !isFeeUnavailable ? .tap(openPicker) : .none
        )
    }

    private func isNetworkFeePickerTransaction(_ transaction: TransactionConfirmationModel) -> Bool {
        switch transaction.transaction {
        case .transfer(.tronUSDT):
            true
        case .transfer(.multichain):
            !transaction.availableExtraTypes.isEmpty
        default:
            false
        }
    }

    private func feeTitle(transaction: TransactionConfirmationModel) -> String {
        if isNetworkFeePickerTransaction(transaction) {
            return TKLocales.FeeMethodPicker.title
        }
        return TKLocales.EventDetails.fee
    }

    private func actionBar(model: TransactionConfirmationModel) -> ConfirmActionBarState {
        let kind: ConfirmActionBarState.Kind = if configurationAssembly.configuration.isConfirmButtonInsteadSlider {
            .button(title: confirmButtonTitle(transaction: model.transaction))
        } else {
            .slider(title: TKLocales.Actions.Confirm.title, subtitle: TKLocales.Actions.Confirm.subtitle)
        }
        return ConfirmActionBarState(
            kind: kind,
            isEnabled: isConfirmEnabled(transaction: model),
            process: state,
            successTitle: TKLocales.Result.success,
            failureTitle: TKLocales.Result.failure,
            resetToken: sliderResetToken,
            onConfirm: { [weak self] in
                self?.confirmAction(model: model)
            }
        )
    }

    private func confirmButtonTitle(transaction: TransactionConfirmationModel.Transaction) -> String {
        switch transaction {
        case let .staking(staking):
            switch staking.flow {
            case .deposit:
                TKLocales.TransactionConfirmation.Buttons.confirmAndStake
            case let .withdraw(isCollect):
                isCollect
                    ? TKLocales.TransactionConfirmation.Buttons.confirmAndCollect
                    : TKLocales.TransactionConfirmation.Buttons.confirmAndUnstake
            }
        case .transfer:
            TKLocales.TransactionConfirmation.Buttons.confirmAndSend
        }
    }

    private func getRates(
        model: TransactionConfirmationModel,
        currency: Currency
    ) async -> (
        valueRate: Rates.Rate?,
        feeRate: Rates.Rate?,
        tonRate: Rates.Rate?,
        trxRate: Rates.Rate?,
        usdtFiatRate: Rates.Rate?
    ) {
        enum Token {
            case ton
            case jetton(JettonInfo)
            case trx
        }

        let valueToken: Token?
        switch model.amount?.token {
        case let .ton(tonToken):
            switch tonToken {
            case .ton: valueToken = .ton
            case let .jetton(item): valueToken = .jetton(item.jettonInfo)
            }
        case .tronTRX: valueToken = .trx
        case .tronUSDT, .multichain: valueToken = nil
        case .none: valueToken = nil
        }

        let feeToken: Token?
        switch model.extraState {
        case .loading, .none: feeToken = nil
        case let .extra(extra):
            switch extra.value {
            case .default:
                feeToken = .ton
            case let .gasless(token, _):
                if token.symbol?.uppercased() == TRX.symbol.uppercased() {
                    feeToken = .trx
                } else {
                    feeToken = .jetton(token)
                }
            case .battery: feeToken = .none
            case .multichain: feeToken = .none
            }
        }

        let shouldLoadTRXRate = model.availableExtraTypes.contains {
            if case let .gasless(token) = $0 {
                return token.symbol?.uppercased() == TRX.symbol.uppercased()
            }
            return false
        }

        var jettonsForRates = Set<String>()
        for token in [valueToken, feeToken] {
            switch token {
            case .ton:
                continue
            case let .jetton(jettonInfo):
                if jettonInfo.symbol?.uppercased() == TRX.symbol.uppercased() {
                    jettonsForRates.insert(TRX.symbol.uppercased())
                } else {
                    jettonsForRates.insert(jettonInfo.address.toRaw())
                }
            case .trx:
                jettonsForRates.insert(TRX.symbol.uppercased())
            case nil:
                continue
            }
        }
        if shouldLoadTRXRate {
            jettonsForRates.insert(TRX.symbol.uppercased())
        }

        do {
            let rates = try await ratesService.loadRates(
                jettons: Array(jettonsForRates),
                currencies: [currency]
            )

            let tonRate = rates.ton.first(where: { $0.currency == currency })
            let trxRate = rates.jettonRates.first {
                $0.key.uppercased() == TRX.symbol.uppercased()
            }?
                .value
                .first(where: { $0.currency == currency })

            let valueRate: Rates.Rate?
            switch valueToken {
            case .ton:
                valueRate = tonRate
            case let .jetton(jettonInfo):
                if jettonInfo.symbol?.uppercased() == TRX.symbol.uppercased() {
                    valueRate = trxRate
                } else {
                    valueRate = rates.jettonRates.first(where: { $0.key == jettonInfo.address.toRaw() })?
                        .value
                        .first(where: { $0.currency == currency })
                }
            case .trx:
                valueRate = trxRate
            case nil:
                valueRate = nil
            }

            let feeRate: Rates.Rate?
            if case let .extra(extra) = model.extraState,
               case let .multichain(feeAsset, _) = extra.value
            {
                feeRate = multichainFeeRate(
                    feeAsset: feeAsset,
                    transaction: model.transaction,
                    wallet: model.wallet,
                    currency: currency
                )
            } else {
                switch feeToken {
                case .ton:
                    feeRate = tonRate
                case let .jetton(jettonInfo):
                    if jettonInfo.symbol?.uppercased() == TRX.symbol.uppercased() {
                        feeRate = trxRate
                    } else {
                        feeRate = rates.jettonRates.first(where: { $0.key == jettonInfo.address.toRaw() })?
                            .value
                            .first(where: { $0.currency == currency })
                    }
                case .trx:
                    feeRate = trxRate
                case .none:
                    feeRate = nil
                }
            }

            let usdtFiatRate = rates.usdt.first(where: { $0.currency == currency })

            return (valueRate, feeRate, tonRate, trxRate, usdtFiatRate)
        } catch {
            return (nil, nil, nil, nil, nil)
        }
    }

    private func multichainConvertedAmount(
        amount: BigUInt,
        asset: MultichainAsset,
        currency: Currency
    ) -> String? {
        guard let price = multichainPrice(asset: asset, currency: currency),
              let decimalAmount = Decimal(string: amount.description, locale: Locale(identifier: "en_US_POSIX"))
        else {
            return nil
        }

        let divisor = decimalPowerOfTen(asset.asset.decimals)
        let fiatAmount = decimalAmount / divisor * price
        return amountFormatter.format(
            decimal: fiatAmount,
            accessory: .fiat(currency),
            style: .compact
        )
    }

    /// The fee asset is not always the asset being transferred — an EVM withdrawal spends USDC and
    /// pays the fee in ETH — and only `MultichainAsset` carries a price, so fall back to the cached
    /// balance entry when the ids differ.
    private func multichainFeeRate(
        feeAsset: MultichainAssetDetails,
        transaction: TransactionConfirmationModel.Transaction,
        wallet: Wallet,
        currency: Currency
    ) -> Rates.Rate? {
        if case let .transfer(.multichain(asset)) = transaction,
           feeAsset.assetId == asset.asset.assetId
        {
            return multichainRate(asset: asset, currency: currency)
        }
        guard let asset = multichainAssetBalanceProvider.cachedAsset(
            for: feeAsset.assetId,
            wallet: wallet
        ) else {
            return nil
        }
        return multichainRate(asset: asset, currency: currency)
    }

    private func multichainRate(
        asset: MultichainAsset,
        currency: Currency
    ) -> Rates.Rate? {
        guard let price = multichainPrice(asset: asset, currency: currency) else {
            return nil
        }
        return Rates.Rate(
            currency: currency,
            rate: price,
            diff24h: nil
        )
    }

    private func multichainPrice(
        asset: MultichainAsset,
        currency: Currency
    ) -> Decimal? {
        let prices = asset.price.prices
        let value = prices[currency.code]
            ?? prices[currency.code.lowercased()]
            ?? prices[currency.code.uppercased()]
        guard let value, value.isFinite else {
            return nil
        }
        return Decimal(value)
    }

    private func decimalPowerOfTen(_ exponent: Int) -> Decimal {
        guard exponent > 0 else {
            return 1
        }
        var result = Decimal(1)
        for _ in 0 ..< exponent {
            result *= 10
        }
        return result
    }

    private struct FeeOptionPresentation {
        let description: String?
        let isEnabled: Bool
    }

    private func feeOptionPresentation(
        transaction: TransactionConfirmationModel,
        extraOption: TransactionConfirmationModel.ExtraOption?,
        currency: Currency,
        tonRate: Rates.Rate?,
        trxRate: Rates.Rate?
    ) -> FeeOptionPresentation {
        let description = extraOption.flatMap { option in
            self.textFormatter.formatFeeOptionDescription(
                feeKind: self.feeCalculator.feeKind(
                    value: option.value,
                    wallet: transaction.wallet
                ),
                currency: currency,
                tonRate: tonRate,
                trxRate: trxRate
            )
        }

        guard isNetworkFeePickerTransaction(transaction) else {
            return FeeOptionPresentation(
                description: description,
                isEnabled: true
            )
        }

        guard isFeeOptionInsufficient(
            transaction: transaction,
            extraOption: extraOption,
            walletBalance: walletBalance
        ) else {
            return FeeOptionPresentation(
                description: description,
                isEnabled: true
            )
        }

        return FeeOptionPresentation(
            description: description,
            isEnabled: false
        )
    }

    private func isFeeOptionInsufficient(
        transaction: TransactionConfirmationModel,
        extraOption: TransactionConfirmationModel.ExtraOption?,
        walletBalance: KeeperCore.WalletBalance?
    ) -> Bool {
        if case .transfer(.multichain) = transaction.transaction {
            return extraOption?.isInsufficient ?? false
        }

        guard let extraValue = extraOption?.value else {
            return false
        }
        guard let walletBalance else {
            return false
        }

        switch extraValue {
        case let .battery(charges, _):
            guard let requiredCharges = charges, requiredCharges > 0 else {
                return false
            }
            let availableCharges = batteryChargesBalance(walletBalance: walletBalance)
            return availableCharges < requiredCharges

        case let .default(amount):
            let tonBalance = BigUInt(max(walletBalance.balance.tonBalance.amount, 0))
            // Sending the TON fee also needs its own gas buffer; mirror the send path's requirement.
            return tonBalance < TronUSDTTonFeePaymentBuilder.requiredTonBalance(for: amount)

        case let .gasless(token, amount):
            if token.symbol?.uppercased() == TRX.symbol.uppercased() {
                let trxBalance = walletBalance.tronBalance?.trxAmount ?? 0
                // A TRX transfer and a TRX-paid fee come out of the same balance.
                let transferred: BigUInt = if case .transfer(.tronTRX) = transaction.transaction {
                    transaction.amount?.value ?? 0
                } else {
                    0
                }
                return trxBalance < transferred + amount
            } else {
                return false
            }

        case .multichain:
            return false
        }
    }

    private func isFeeOptionRefillable(
        transaction: TransactionConfirmationModel,
        extraOption: TransactionConfirmationModel.ExtraOption?
    ) -> Bool {
        guard case let .transfer(.multichain(asset)) = transaction.transaction,
              asset.asset.chain == .ton,
              case let .gasless(_, feeAmount) = extraOption?.value,
              let amount = transaction.amount?.value
        else {
            return true
        }
        return feeAmount < amount
    }

    private func isConfirmEnabled(transaction: TransactionConfirmationModel) -> Bool {
        guard case .extra = transaction.extraState else {
            return false
        }
        return !isSelectedFeeInsufficient(transaction: transaction)
    }

    private func isSelectedFeeInsufficient(transaction: TransactionConfirmationModel) -> Bool {
        guard case let .extra(extra) = transaction.extraState else {
            return false
        }
        let extraOption = transaction.extraOptions.first { $0.type == extra.value.extraType }
        return isFeeOptionInsufficient(
            transaction: transaction,
            extraOption: extraOption,
            walletBalance: walletBalance
        )
    }

    /// A multichain transfer gets this switch from its controller.
    private func preselectPayableTronFeeIfNeeded(_ model: TransactionConfirmationModel) -> Bool {
        guard case .transfer(.tronUSDT) = model.transaction,
              !hasUserSelectedFeeMethod,
              let payableType = model.payableTronFeeType(isInsufficient: {
                  isFeeOptionInsufficient(transaction: model, extraOption: $0, walletBalance: walletBalance)
              })
        else {
            return false
        }
        confirmationController.setPrefferedExtraType(extraType: payableType)
        return true
    }

    private func reportInsufficientTronFeeIfNeeded(_ model: TransactionConfirmationModel) {
        guard let shortage = model.tronFeeShortage(isInsufficient: {
            isFeeOptionInsufficient(transaction: model, extraOption: $0, walletBalance: walletBalance)
        }) else {
            return
        }
        didDetectInsufficientTronFee?(shortage)
    }

    private func tronFeeBalanceAvailabilityText(
        transaction: TransactionConfirmationModel,
        feeDetails: TransactionConfirmationFeeCalculator.FeeDetails
    ) -> String? {
        switch transaction.transaction {
        case .transfer(.tronUSDT), .transfer(.tronTRX):
            break
        default:
            return nil
        }
        guard let walletBalance else {
            return nil
        }

        switch feeDetails.kind {
        case .battery:
            let availableCharges = batteryChargesBalance(walletBalance: walletBalance)
            return TKLocales.TronUsdtFees.TransactionConfirmation.outOfAvailable("\(availableCharges)")

        case let .token(_, _, _, tokenKind):
            let availableText: String?
            switch tokenKind {
            case .ton:
                let availableTON = BigUInt(max(walletBalance.balance.tonBalance.amount, 0))
                availableText = amountFormatter.format(
                    amount: availableTON,
                    fractionDigits: TonInfo.fractionDigits,
                    accessory: .tokenSymbol(TonInfo.symbol),
                    isNegative: false,
                    style: .compact
                )

            case .trx:
                let availableTRX = walletBalance.tronBalance?.trxAmount ?? 0
                availableText = amountFormatter.format(
                    amount: availableTRX,
                    fractionDigits: TRX.fractionDigits,
                    accessory: .tokenSymbol(TRX.symbol),
                    isNegative: false,
                    style: .compact
                )

            case .other:
                availableText = nil
            }

            guard let availableText else {
                return nil
            }
            return TKLocales.TronUsdtFees.TransactionConfirmation.outOfAvailable(availableText)
        }
    }

    private func batteryChargesBalance(walletBalance: KeeperCore.WalletBalance) -> Int {
        guard
            let batteryBalance = walletBalance.batteryBalance,
            let charges = batteryCalculation.calculateAvailableCharges(balance: batteryBalance)
        else {
            return 0
        }
        return charges
    }

    private func loadWalletBalance(wallet: Wallet, currency: Currency) async -> KeeperCore.WalletBalance? {
        // Load a fresh balance so a just-completed fee refill isn't masked by a stale cache (the
        // insufficiency checks below read this balance); fall back to the cache only on failure.
        if let fresh = try? await balanceService.loadWalletBalance(
            wallet: wallet,
            currency: currency,
            includingTransferFees: true
        ) {
            return fresh
        }
        return try? balanceService.getBalance(wallet: wallet)
    }

    private func confirmAction(model: TransactionConfirmationModel) {
        confirmTask?.cancel()
        confirmTask = Task { [weak self] in
            guard let self else { return }
            defer { confirmTask = nil }

            didStartConfirmTransaction?(model)
            let didCancelTransaction = self.didCancelTransaction
            let result = await withTaskCancellationHandler(
                operation: {
                    await self.runConfirmAction(model: model)
                },
                onCancel: {
                    didCancelTransaction?()
                }
            )
            guard !Task.isCancelled else { return }

            switch result {
            case .cancelledByUser:
                sliderResetToken += 1
                state = .idle
                didCancelTransaction?()
            case let .insufficientFunds(error):
                state = .failed
                didFailTransaction?(model, error)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                state = .idle
                didProduceInsufficientFundsError?(error)
            case let .failure(error):
                handleError(error)
                if case .multichainTransactionFailure(.relayerOutcomeUnknown) = error {
                    isRetryUnsafe = true
                }
                state = .failed
                didFailTransaction?(model, error)
                guard !isRetryUnsafe else { return }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                state = .idle
            case .success:
                state = .success
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                NotificationCenter.default.postTransactionSendNotification(
                    wallet: model.wallet,
                    patch: { [transactionSentNotificationPatch] userInfo in
                        if !model.hasHistoryFeed {
                            userInfo[Notification.transactionSendWithoutHistoryKey] = true
                        }
                        transactionSentNotificationPatch(&userInfo)
                    }
                )
                didConfirmTransaction?(model)
            }
        }
    }

    private func runConfirmAction(model: TransactionConfirmationModel) async -> ConfirmActionResult {
        if model.isMaxAmountUsed {
            let tokenName = model.amount?.token.symbol ?? "Token"
            let confirmed = await withCheckedContinuation { continuation in
                didRequestSendAllConfirmation?(tokenName) { confirmed in
                    continuation.resume(returning: confirmed)
                }
            }
            guard !Task.isCancelled else {
                return .cancelledByUser
            }
            guard confirmed else {
                return .cancelledByUser
            }
        }

        state = .processing

        do {
            try await fundsValidator.validateFundsIfNeeded(wallet: model.wallet, emulationModel: model)
        } catch {
            return .insufficientFunds(error)
        }
        guard !Task.isCancelled else {
            return .cancelledByUser
        }

        let result = await confirmationController.sendTransaction()
        if case let .success(sendResult) = result {
            await pendingTransactionsService.record(
                sendResult,
                wallet: confirmationController.getModel().wallet
            )
        }
        guard !Task.isCancelled else {
            return .cancelledByUser
        }

        switch result {
        case .success:
            return .success
        case let .failure(error):
            if case .cancelledByUser = error {
                return .cancelledByUser
            }
            return .failure(error)
        }
    }
}

private extension TransactionConfirmationViewModelImplementation {
    func makeFeePickerPresentation(
        currency: Currency,
        tonRate: Rates.Rate?,
        trxRate: Rates.Rate?,
        title: String,
        subtitle: String?,
        skeletonItemCount: Int
    ) -> NetworkFeePickerPresentation {
        let dataSource = LazyNetworkFeePickerDataSource { [weak self] in
            guard let self else {
                return .uncategorized(dataSource: StaticNetworkFeePickerDataSource(items: []))
            }
            await self.confirmationController.prepareFeeOptions()
            let items = self.makeFeePickerItems(
                transaction: self.confirmationController.getModel(),
                currency: currency,
                tonRate: tonRate,
                trxRate: trxRate
            )
            return .uncategorized(dataSource: StaticNetworkFeePickerDataSource(items: items))
        }

        return NetworkFeePickerPresentation(
            configuration: NetworkFeePickerConfiguration(
                title: title,
                subtitle: subtitle,
                skeletonItemCount: skeletonItemCount
            ),
            dataSource: dataSource,
            didSelectItem: { [weak self] item, _ in
                guard let self,
                      let index = Int(item.id)
                else {
                    return
                }
                let transaction = self.confirmationController.getModel()
                guard transaction.availableExtraTypes.indices.contains(index) else {
                    return
                }
                let extraType = transaction.availableExtraTypes[index]
                let extraOption = transaction.extraOptions.first { $0.type == extraType }

                if self.isFeeOptionInsufficient(
                    transaction: transaction,
                    extraOption: extraOption,
                    walletBalance: self.walletBalance
                ) {
                    guard self.isFeeOptionRefillable(
                        transaction: transaction,
                        extraOption: extraOption
                    ) else {
                        return
                    }
                    self.didRequestOpenFeeRefill?(extraType)
                    return
                }

                self.hasUserSelectedFeeMethod = true
                self.confirmationController.setPrefferedExtraType(extraType: extraType)
                self.update()
            }
        )
    }

    func makeFeePickerItems(
        transaction: TransactionConfirmationModel,
        currency: Currency,
        tonRate: Rates.Rate?,
        trxRate: Rates.Rate?
    ) -> [NetworkFeePickerItem] {
        let selectedExtraType: TransactionConfirmationModel.ExtraType? = {
            guard case let .extra(extra) = transaction.extraState else {
                return nil
            }
            return extra.value.extraType
        }()
        return transaction.availableExtraTypes.enumerated().map { index, extraType in
            let extraOption = transaction.extraOptions.first(where: { $0.type == extraType })
            let optionPresentation = feeOptionPresentation(
                transaction: transaction,
                extraOption: extraOption,
                currency: currency,
                tonRate: tonRate,
                trxRate: trxRate
            )
            let isRefillable = isFeeOptionRefillable(
                transaction: transaction,
                extraOption: extraOption
            )
            let subtitle = optionPresentation.description
            let text: NetworkFeePickerItem.Text = if let subtitle {
                .titled(
                    title: extraType.networkFeePickerTitle,
                    subtitle: subtitle
                )
            } else {
                .singleLine(title: extraType.networkFeePickerTitle)
            }

            return NetworkFeePickerItem(
                id: "\(index)",
                leading: extraType.networkFeePickerLeading,
                text: text,
                isDisabled: !optionPresentation.isEnabled,
                actionTitle: optionPresentation.isEnabled || !isRefillable
                    ? nil
                    : TKLocales.FeeMethodPicker.deposit,
                isSelected: extraType == selectedExtraType
            )
        }
    }
}

private extension TransactionConfirmationViewModelImplementation {
    enum ConfirmActionResult {
        case cancelledByUser
        case insufficientFunds(InsufficientFundsError)
        case failure(TransactionConfirmationError)
        case success
    }
}
