import BigInt
import KeeperCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import TronSwift
import UIKit

public struct WithdrawDisplayInfo {
    public let symbol: String
    public let imageUrl: String?
    public let networkName: String
    public let networkType: String
    public let estimatedDurationSeconds: Int?
    public let withdrawalFeeUsd: Double?

    public init(
        symbol: String,
        imageUrl: String?,
        networkName: String,
        networkType: String,
        estimatedDurationSeconds: Int?,
        withdrawalFeeUsd: Double?
    ) {
        self.symbol = symbol
        self.imageUrl = imageUrl
        self.networkName = networkName
        self.networkType = networkType
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.withdrawalFeeUsd = withdrawalFeeUsd
    }
}

@MainActor
protocol TransactionConfirmationOutput: AnyObject {
    var didRequireSign: ((TransferData, Wallet) async throws(WalletTransferSignError) -> SignedTransactions)? { get set }
    var didStartEmulation: (() -> Void)? { get set }
    var didFinishEmulation: ((TransactionConfirmationError?) -> Void)? { get set }
    var didCancelEmulation: (() -> Void)? { get set }
    var didStartConfirmTransaction: ((TransactionConfirmationModel) -> Void)? { get set }
    var didConfirmTransaction: ((TransactionConfirmationModel) -> Void)? { get set }
    var didFailTransaction: ((TransactionConfirmationModel, any AnalyticsError) -> Void)? { get set }
    var didCancelTransaction: (() -> Void)? { get set }
    var didProduceInsufficientFundsError: ((_ error: InsufficientFundsError) -> Void)? { get set }
    var didRequestOpenFeeRefill: ((_ extraType: TransactionConfirmationModel.ExtraType) -> Void)? { get set }
    var didClose: (() -> Void)? { get set }
}

@MainActor
public protocol TransactionConfirmationViewModel: AnyObject {
    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }
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
    var didStartConfirmTransaction: ((TransactionConfirmationModel) -> Void)?
    var didConfirmTransaction: ((TransactionConfirmationModel) -> Void)?
    var didFailTransaction: ((TransactionConfirmationModel, any AnalyticsError) -> Void)?
    var didCancelTransaction: (() -> Void)?
    var didProduceInsufficientFundsError: ((_ error: InsufficientFundsError) -> Void)?
    var didRequestOpenFeeRefill: ((_ extraType: TransactionConfirmationModel.ExtraType) -> Void)?
    var didClose: (() -> Void)?
    var didRequestSendAllConfirmation: ((String, @escaping (Bool) -> Void) -> Void)?

    // MARK: - TransactionConfirmationViewModel

    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?

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

    // MARK: - State

    private enum State {
        case idle
        case processing
        case success
        case failed
    }

    private var state: State = .idle {
        didSet {
            let model = confirmationController.getModel()
            update(with: model)
        }
    }

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
    private let amountFormatter: AmountFormatter
    private let fundsValidator: InsufficientFundsValidator
    private let currencyStore: CurrencyStore
    private let ratesService: RatesService
    private let balanceService: BalanceService
    private let batteryCalculation: BatteryCalculation
    private let feeCalculator: TransactionConfirmationFeeCalculator
    private let textFormatter: TransactionConfirmationTextFormatter
    private let configurationAssembly: ConfigurationAssembly
    private let withdrawDisplayInfo: WithdrawDisplayInfo?

    // MARK: - Init

    init(
        confirmationController: TransactionConfirmationController,
        amountFormatter: AmountFormatter,
        fundsValidator: InsufficientFundsValidator,
        currencyStore: CurrencyStore,
        ratesService: RatesService,
        balanceService: BalanceService,
        batteryCalculation: BatteryCalculation,
        configurationAssembly: ConfigurationAssembly,
        withdrawDisplayInfo: WithdrawDisplayInfo? = nil
    ) {
        self.confirmationController = confirmationController
        self.amountFormatter = amountFormatter
        self.fundsValidator = fundsValidator
        self.currencyStore = currencyStore
        self.ratesService = ratesService
        self.balanceService = balanceService
        self.configurationAssembly = configurationAssembly
        self.batteryCalculation = batteryCalculation
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
            let model = confirmationController.getModel()
            let currency = currencyStore.state
            let rates = await getRates(model: model, currency: currency)
            guard !Task.isCancelled else { return }
            self.amountRate = rates.valueRate
            self.feeRate = rates.feeRate
            self.tonRate = rates.tonRate
            self.trxRate = rates.trxRate
            self.usdtFiatRate = rates.usdtFiatRate
            self.walletBalance = await loadWalletBalance(
                wallet: model.wallet,
                currency: currency
            )
            update(with: model)

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

        var items = [TKPopUp.Item]()

        items.append(createHeaderImageItem(transaction: model))

        let caption: String = {
            switch model.transaction {
            case .staking:
                return TKLocales.TransactionConfirmation.confirmAction
            case let .transfer(transfer):
                switch transfer {
                case .jetton, .ton, .tronUSDT:
                    return TKLocales.TransactionConfirmation.confirmAction
                case let .nft(nft):
                    var result = nft.notNilName
                    if let collectionName = nft.collection?.notEmptyName {
                        result += " · "
                        result += collectionName
                    }
                    return result
                }
            }
        }()
        items.append(
            TKPopUp.Component.GroupComponent(
                padding: UIEdgeInsets(top: 0, left: 32, bottom: 32, right: 32),
                items: [
                    TKPopUp.Component.LabelComponent(
                        text: caption.withTextStyle(
                            .body1,
                            color: .Text.secondary,
                            alignment: .center,
                            lineBreakMode: .byTruncatingTail
                        ),
                        numberOfLines: 1,
                        bottomSpace: 4
                    ),
                    createActionNameItem(transaction: model.transaction),
                ]
            )
        )
        items.append(TKPopUp.Component.GroupComponent(
            padding: UIEdgeInsets(top: 0, left: 16, bottom: withdrawDisplayInfo != nil ? 0 : 16, right: 16),
            items: [createListItem(transaction: model, amountRate: amountRate, feeRate: feeRate, tonRate: tonRate, trxRate: trxRate, usdtFiatRate: usdtFiatRate, currency: currency)]
        ))

        if withdrawDisplayInfo != nil {
            items.append(ChangellyDisclaimerPopUpItem(bottomSpace: 0))
        }

        let bottomItems: [TKPopUp.Item] = [
            createActionBar(model: model),
        ]

        let configuration = TKPopUp.Configuration(
            items: items,
            bottomItems: bottomItems
        )

        didUpdateConfiguration?(configuration)
    }

    private func createActionNameItem(transaction: TransactionConfirmationModel.Transaction) -> TKPopUp.Item {
        let text: String = {
            if let info = withdrawDisplayInfo {
                return "\(TKLocales.Ramp.Withdraw.title) \(info.symbol)"
            }
            switch transaction {
            case let .staking(staking):
                switch staking.flow {
                case .withdraw:
                    return TKLocales.TransactionConfirmation.unstake
                case .deposit:
                    return TKLocales.TransactionConfirmation.deposit
                }
            case let .transfer(transfer):
                switch transfer {
                case let .jetton(jettonInfo):
                    return "\(jettonInfo.symbol ?? jettonInfo.name) transfer"
                case .ton:
                    return "\(TonInfo.symbol) transfer"
                case .nft:
                    return "NFT transfer"
                case .tronUSDT:
                    return "Transfer \(TronSwift.USDT.name)"
                }
            }
        }()
        return TKPopUp.Component.LabelComponent(
            text: text.withTextStyle(
                .h3,
                color: .Text.primary,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            ),
            numberOfLines: 1,
            bottomSpace: 0
        )
    }

    private func createHeaderImageItem(transaction: TransactionConfirmationModel) -> TKPopUp.Item {
        let image: TKImage
        let corners: TKImageView.Corners
        let badgeImage: TKImage?

        if let info = withdrawDisplayInfo, let imageUrlString = info.imageUrl, let url = URL(string: imageUrlString) {
            image = .urlImage(url)
            badgeImage = nil
            corners = .circle
        } else {
            switch transaction.transaction {
            case let .staking(staking):
                image = .image(staking.pool.bigIcon)
                badgeImage = nil
                corners = .circle
            case let .transfer(transfer):
                switch transfer {
                case let .jetton(jettonInfo):
                    image = .urlImage(jettonInfo.imageURL)
                    badgeImage = transaction.wallet.isTronTurnOn && jettonInfo.isTonUSDT ? .image(.App.Currency.Vector.ton) : nil
                    corners = .circle
                case .ton:
                    image = .image(.App.Currency.Vector.ton)
                    badgeImage = nil
                    corners = .circle
                case let .nft(nft):
                    image = .urlImage(nft.imageURL)
                    badgeImage = nil
                    corners = .cornerRadius(cornerRadius: 12)
                case .tronUSDT:
                    image = .image(.App.Currency.Size96.usdt)
                    badgeImage = .image(.App.Currency.Vector.trc20)
                    corners = .circle
                }
            }
        }

        var badge: TransactionConfirmationHeaderImageItemView.Configuration.Badge?
        if let badgeImage {
            badge = TransactionConfirmationHeaderImageItemView.Configuration.Badge(
                image: badgeImage
            )
        }

        return TransactionConfirmationHeaderImageItem(
            configuration: TransactionConfirmationHeaderImageItemView.Configuration(
                image: image,
                corners: corners,
                badge: badge
            ),
            bottomSpace: 20
        )
    }

    private func createListItem(
        transaction: TransactionConfirmationModel,
        amountRate: Rates.Rate?,
        feeRate: Rates.Rate?,
        tonRate: Rates.Rate?,
        trxRate: Rates.Rate?,
        usdtFiatRate: Rates.Rate?,
        currency: Currency
    ) -> TKPopUp.Item {
        var items = [TKListContainerItem]()

        items.append(
            createWalletItem(transaction: transaction)
        )
        if let recipientItem = createRecipientItem(transaction: transaction) {
            items.append(recipientItem)
        }
        if let recipientAddress = createRecipientAddresItem(transaction: transaction) {
            items.append(recipientAddress)
        }
        if let networkItem = createNetworkItem() {
            items.append(networkItem)
        }
        if let amountItem = createAmountItem(transaction: transaction, rate: amountRate, currency: currency) {
            items.append(amountItem)
        }
        if let apyItem = createAPYItem(transaction: transaction) {
            items.append(
                apyItem
            )
        }
        if let withdrawalFeeItem = createWithdrawalFeeItem(usdtFiatRate: usdtFiatRate, currency: currency) {
            items.append(withdrawalFeeItem)
        }
        items.append(
            createFeeListItem(
                transaction: transaction,
                rate: feeRate,
                tonRate: tonRate,
                trxRate: trxRate,
                currency: currency
            )
        )
        if let withdrawalTimeItem = createWithdrawalTimeItem() {
            items.append(withdrawalTimeItem)
        }
        if let commentItem = createCommentItem(transaction: transaction) {
            items.append(commentItem)
        }

        let configuration = TKListContainerView.Configuration(
            items: items,
            copyToastConfiguration: .copied
        )
        return TKPopUp.Component.List(
            configuration: configuration,
            bottomSpace: 16
        )
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

    private func createWalletItem(transaction: TransactionConfirmationModel) -> TKListContainerItemView.Model {
        return TKListContainerItemView.Model(
            title: TKLocales.TransactionConfirmation.wallet,
            value: .value(
                TransactionConfirmationListContainerItemWalletValueView.Configuration(
                    wallet: transaction.wallet
                )
            ),
            action: nil
        )
    }

    private func createRecipientItem(transaction: TransactionConfirmationModel) -> TKListContainerItem? {
        guard let recipient = transaction.recipient else { return nil }
        return TKListContainerItemView.Model(
            title: TKLocales.TransactionConfirmation.recipient,
            value: .value(
                TKListContainerItemDefaultValueView.Model(
                    topValue: TKListContainerItemDefaultValueView.Model.Value(value: recipient)
                )
            ),
            action: .copy(copyValue: recipient)
        )
    }

    private func createRecipientAddresItem(transaction: TransactionConfirmationModel) -> TKListContainerItem? {
        guard let recipientAddress = transaction.recipientAddress else { return nil }
        return TKListContainerFullValueItemItem(
            title: TKLocales.TransactionConfirmation.recipient,
            value: recipientAddress,
            copyValue: recipientAddress
        )
    }

    private func createNetworkItem() -> TKListContainerItem? {
        guard let info = withdrawDisplayInfo else { return nil }
        let networkLabel = RampItemConfigurator.networkLabel(network: info.networkType, networkName: info.networkName)

        return TKListContainerItemView.Model(
            title: TKLocales.Ramp.Deposit.network,
            value: .value(
                TKListContainerItemDefaultValueView.Model(
                    topValue: TKListContainerItemDefaultValueView.Model.Value(value: info.networkName),
                    bottomValue: TKListContainerItemDefaultValueView.Model.Value(value: networkLabel)
                )
            ),
            action: nil
        )
    }

    private func createWithdrawalTimeItem() -> TKListContainerItem? {
        guard let info = withdrawDisplayInfo, let seconds = info.estimatedDurationSeconds else { return nil }
        let minutes = max(1, (seconds + 59) / 60)
        let timeText = TKLocales.Ramp.Deposit.upToMin(minutes)
        return TKListContainerItemView.Model(
            title: TKLocales.Ramp.Withdraw.withdrawalTime,
            value: .value(
                TKListContainerItemDefaultValueView.Model(
                    topValue: TKListContainerItemDefaultValueView.Model.Value(value: timeText)
                )
            ),
            action: nil
        )
    }

    private func createWithdrawalFeeItem(usdtFiatRate: Rates.Rate?, currency: Currency) -> TKListContainerItem? {
        guard let info = withdrawDisplayInfo,
              let feeUsd = info.withdrawalFeeUsd,
              feeUsd > 0
        else { return nil }

        let feeDecimal = Decimal(feeUsd)
        let topFormatted = amountFormatter.format(
            decimal: feeDecimal,
            accessory: .symbol(info.symbol, onLeft: false),
            style: .compact
        )
        let topValue = "\(TKLocales.Common.Numbers.approximate) \(topFormatted)"

        let bottomFormatted: String
        if let usdtFiatRate {
            let converted = feeDecimal * usdtFiatRate.rate
            bottomFormatted = amountFormatter.format(
                decimal: converted,
                accessory: .currency(currency),
                style: .compact
            )
        } else {
            bottomFormatted = amountFormatter.format(
                decimal: feeDecimal,
                accessory: .currency(Currency.USD),
                style: .compact
            )
        }
        let bottomValue = "\(TKLocales.Common.Numbers.approximate) \(bottomFormatted)"

        return TKListContainerItemView.Model(
            title: TKLocales.Ramp.Withdraw.withdrawalFee,
            value: .value(
                TKListContainerItemDefaultValueView.Model(
                    topValue: TKListContainerItemDefaultValueView.Model.Value(value: topValue),
                    bottomValue: TKListContainerItemDefaultValueView.Model.Value(value: bottomValue)
                )
            ),
            action: nil
        )
    }

    private func createCommentItem(transaction: TransactionConfirmationModel) -> TKListContainerItem? {
        guard let comment = transaction.comment, !comment.isEmpty else { return nil }
        return TKListContainerItemView.Model(
            title: TKLocales.TransactionConfirmation.comment,
            value: .value(
                TKListContainerItemDefaultValueView.Model(
                    topValue: TKListContainerItemDefaultValueView.Model.Value(value: comment)
                )
            ),
            action: .copy(copyValue: comment)
        )
    }

    private func createAPYItem(transaction: TransactionConfirmationModel) -> TKListContainerItemView.Model? {
        guard case let .staking(staking) = transaction.transaction,
              case .deposit = staking.flow else { return nil }

        let apyPercents = amountFormatter.format(
            decimal: staking.pool.apy,
            accessory: .none,
            style: .compact
        )
        let value = "\(TKLocales.Common.Numbers.approximate) \(apyPercents)%"
        return TKListContainerItemView.Model(
            title: TKLocales.TransactionConfirmation.apy,
            value: .value(
                TKListContainerItemDefaultValueView.Model(
                    topValue: TKListContainerItemDefaultValueView.Model.Value(value: value)
                )
            ),
            action: .copy(copyValue: apyPercents)
        )
    }

    private func createAmountItem(
        transaction: TransactionConfirmationModel,
        rate: Rates.Rate?,
        currency: Currency
    ) -> TKListContainerItemView.Model? {
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
            case .jetton, .ton, .tronUSDT:
                title = TKLocales.TransactionConfirmation.amount
            case .nft:
                return nil
            }
        }

        guard let amount = transaction.amount else { return nil }

        let value: TKListContainerItemView.Model.Value
        let valueFormatted = amountFormatter.format(
            amount: amount.value,
            fractionDigits: amount.token.fractionDigits,
            accessory: .symbol(amount.token.symbol),
            isNegative: false,
            style: .exactValue
        )
        var convertedFormatted: String?
        if let rate {
            let converted = RateConverter().convert(
                amount: amount.value,
                amountFractionLength: amount.token.fractionDigits,
                rate: rate
            )
            let formatted = amountFormatter.format(
                amount: converted.amount,
                fractionDigits: converted.fractionLength,
                accessory: .currency(currency)
            )
            convertedFormatted = formatted
        }
        value = .value(TKListContainerItemDefaultValueView.Model(
            topValue: TKListContainerItemDefaultValueView.Model.Value(value: valueFormatted),
            bottomValue: TKListContainerItemDefaultValueView.Model.Value(value: convertedFormatted)
        ))

        return TKListContainerItemView.Model(
            title: title,
            value: value,
            action: .copy(copyValue: valueFormatted)
        )
    }

    private func createFeeListItem(
        transaction: TransactionConfirmationModel,
        rate: Rates.Rate?,
        tonRate: Rates.Rate?,
        trxRate: Rates.Rate?,
        currency: Currency
    ) -> TKListContainerItemView.Model {
        var captionButton: TKPlainButton.Model?
        var isRefund: Bool = false
        var extraType: TransactionConfirmationModel.ExtraType = .default
        let value: TKListContainerItemView.Model.Value
        switch transaction.extraState {
        case .loading:
            value = .loading

        case let .extra(extra):
            let feeDetails = feeCalculator.feeDetails(extra: extra, wallet: transaction.wallet)
            isRefund = feeDetails.isRefund
            extraType = feeDetails.extraType

            let feeFormatted = textFormatter.formatFeeList(
                fee: feeDetails,
                rate: rate,
                tonRate: tonRate,
                currency: currency
            )
            let tronFeeBalanceAvailability = tronFeeBalanceAvailabilityText(
                transaction: transaction,
                feeDetails: feeDetails
            )

            value = .value(TKListContainerItemDefaultValueView.Model(
                topValue: TKListContainerItemDefaultValueView.Model.Value(value: "\(TKLocales.Common.Numbers.approximate) \(feeFormatted.topValue)"),
                bottomValue: TKListContainerItemDefaultValueView.Model.Value(
                    value: tronFeeBalanceAvailability ?? feeFormatted.bottomValue
                )
            ))

            if transaction.availableExtraTypes.count > 1 {
                captionButton = TKPlainButton.Model(
                    title: TKLocales.Actions.edit.withTextStyle(.body2, color: .Text.accent),
                    icon: TKPlainButton.Model.Icon(
                        image: .TKUIKit.Icons.Size12.chevronRight,
                        tintColor: .Text.accent,
                        padding: .init(top: 4, left: 2, bottom: 4, right: 0)
                    ),
                    action: nil
                )
            }

        case .none:
            value = .value(TKListContainerItemDefaultValueView.Model(
                topValue: TKListContainerItemDefaultValueView.Model.Value(value: "?")
            ))
        }
        return TKListContainerItemView.Model(
            title: isRefund ? TKLocales.EventDetails.refund : TKLocales.EventDetails.fee,
            captionButtonModel: captionButton,
            value: value,
            action: .custom { [weak self] view in
                guard transaction.availableExtraTypes.count > 1, let self else { return }

                let items = transaction.availableExtraTypes.map { item in
                    let optionValue = transaction.extraOptions
                        .first(where: { $0.type == item })?
                        .value
                    let optionPresentation = self.feeOptionPresentation(
                        transaction: transaction,
                        extraType: item,
                        extraValue: optionValue,
                        currency: currency,
                        tonRate: tonRate,
                        trxRate: trxRate
                    )

                    let title = {
                        switch item {
                        case .default:
                            return TKLocales.ExtraType.ton
                        case .battery:
                            return TKLocales.ExtraType.battery
                        case let .gasless(token):
                            return token.symbol ?? token.name
                        }
                    }()

                    let leftIcon: TKImageView.Model? = {
                        switch item {
                        case .default:
                            return TKImageView.Model(
                                image: .image(.TKCore.Icons.Size44.tonLogo),
                                tintColor: nil,
                                corners: .circle
                            )

                        case .battery:
                            return TKImageView.Model(
                                image: .image(.TKUIKit.Icons.Size24.flash),
                                tintColor: .Accent.green,
                                corners: .none
                            )

                        case let .gasless(token):
                            switch token.symbol?.uppercased() {
                            case TRX.symbol.uppercased():
                                return TKImageView.Model(
                                    image: .image(
                                        .App.Currency.Vector.trc20.withRenderingMode(.alwaysOriginal)
                                    ),
                                    tintColor: nil,
                                    corners: .circle
                                )
                            default:
                                return TKImageView.Model(
                                    image: .urlImage(token.imageURL),
                                    tintColor: nil,
                                    corners: .circle
                                )
                            }
                        }
                    }()

                    return TKPopupMenuItem(
                        title: title,
                        value: nil,
                        description: optionPresentation.description,
                        icon: nil,
                        leftIcon: leftIcon,
                        footerText: optionPresentation.footerText,
                        footerActionTitle: optionPresentation.footerActionTitle,
                        footerActionHandler: optionPresentation.footerActionHandler,
                        isEnabled: optionPresentation.isEnabled,
                        selectionHandler: optionPresentation.isEnabled ? { [weak self] in
                            guard let self else { return }
                            if isFeeOptionInsufficient(
                                extraValue: optionValue,
                                walletBalance: walletBalance
                            ) {
                                didRequestOpenFeeRefill?(item)
                                return
                            }
                            confirmationController.setPrefferedExtraType(extraType: item)
                            update()
                        } : nil
                    )
                }

                let selectedIndex = transaction.availableExtraTypes.firstIndex(where: { type in
                    guard type == extraType else { return false }
                    let optionValue = transaction.extraOptions.first(where: { $0.type == type })?.value
                    return self.feeOptionPresentation(
                        transaction: transaction,
                        extraType: type,
                        extraValue: optionValue,
                        currency: currency,
                        tonRate: tonRate,
                        trxRate: trxRate
                    ).isEnabled
                })

                TKPopupMenuController.show(
                    sourceView: view,
                    position: .topRight,
                    width: 0,
                    items: Array(
                        items
                            .enumerated()
                            .map { offset, element in
                                var item = element
                                item.hasSeparator = offset + 1 < items.count
                                return item
                            }
                    ),
                    selectedIndex: selectedIndex
                )
            }
        )
    }

    private func createActionBar(model: TransactionConfirmationModel) -> TKPopUp.Item {
        var items = [TKPopUp.Item]()

        if configurationAssembly.configuration.isConfirmButtonInsteadSlider {
            items.append(createConfirmButton(model: model))
        } else {
            items.append(createConfirmSlider(model: model))
        }

        let itemState: TKProcessContainerView.State = {
            switch state {
            case .idle:
                return .idle
            case .processing:
                return .process
            case .success:
                return .success
            case .failed:
                return .failed
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

    private func createConfirmButton(model: TransactionConfirmationModel) -> TKPopUp.Item {
        let buttonTitle: String = {
            switch model.transaction {
            case let .staking(staking):
                switch staking.flow {
                case .deposit:
                    return TKLocales.TransactionConfirmation.Buttons.confirmAndStake
                case let .withdraw(isCollect):
                    if isCollect {
                        return TKLocales.TransactionConfirmation.Buttons.confirmAndUnstake
                    } else {
                        return TKLocales.TransactionConfirmation.Buttons.confirmAndCollect
                    }
                }
            case .transfer:
                return TKLocales.TransactionConfirmation.Buttons.confirmAndSend
            }
        }()
        var btnConf = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        btnConf.content = .init(title: .plainString(buttonTitle))
        btnConf.action = { [weak self] in
            self?.confirmAction(model: model)
        }

        return TKPopUp.Component.ButtonGroupComponent(buttons: [
            TKPopUp.Component.ButtonComponent(buttonConfiguration: btnConf),
        ])
    }

    private func createConfirmSlider(model: TransactionConfirmationModel) -> TKPopUp.Item {
        let sliderItem = TKPopUp.Component.Slider(
            title: TKLocales.Actions.Confirm.title.withTextStyle(.label1, color: .Text.tertiary, alignment: .center),
            isEnable: true,
            appearance: .standart,
            didConfirm: { [weak self] in
                self?.confirmAction(model: model)
            }
        )

        return TKPopUp.Component.GroupComponent(
            padding: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16),
            items: [
                sliderItem,
            ]
        )
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
        case .tronUSDT: valueToken = nil
        case .none: valueToken = nil
        }

        let feeToken: Token?
        switch model.extraState {
        case .loading, .none: feeToken = nil
        case let .extra(extra):
            switch extra.value {
            case .default: feeToken = .ton
            case let .gasless(token, _):
                if token.symbol?.uppercased() == TRX.symbol.uppercased() {
                    feeToken = .trx
                } else {
                    feeToken = .jetton(token)
                }
            case .battery: feeToken = .none
            }
        }

        let shouldLoadTRXRate: Bool = {
            guard case .transfer(.tronUSDT) = model.transaction else { return false }
            return model.availableExtraTypes.contains {
                if case let .gasless(token) = $0 {
                    return token.symbol?.uppercased() == TRX.symbol.uppercased()
                }
                return false
            }
        }()

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

            let usdtFiatRate = rates.usdt.first(where: { $0.currency == currency })

            return (valueRate, feeRate, tonRate, trxRate, usdtFiatRate)
        } catch {
            return (nil, nil, nil, nil, nil)
        }
    }

    private struct FeeOptionPresentation {
        let description: String?
        let footerText: String?
        let footerActionTitle: String?
        let footerActionHandler: (() -> Void)?
        let isEnabled: Bool
    }

    private func feeOptionPresentation(
        transaction: TransactionConfirmationModel,
        extraType: TransactionConfirmationModel.ExtraType,
        extraValue: TransactionConfirmationModel.ExtraValue?,
        currency: Currency,
        tonRate: Rates.Rate?,
        trxRate: Rates.Rate?
    ) -> FeeOptionPresentation {
        let description = extraValue.flatMap {
            self.textFormatter.formatFeeOptionDescription(
                feeKind: self.feeCalculator.feeKind(
                    value: $0,
                    wallet: transaction.wallet
                ),
                currency: currency,
                tonRate: tonRate,
                trxRate: trxRate
            )
        }

        guard case .transfer(.tronUSDT) = transaction.transaction else {
            return FeeOptionPresentation(
                description: description,
                footerText: nil,
                footerActionTitle: nil,
                footerActionHandler: nil,
                isEnabled: true
            )
        }

        guard isFeeOptionInsufficient(
            extraValue: extraValue,
            walletBalance: walletBalance
        ) else {
            return FeeOptionPresentation(
                description: description,
                footerText: nil,
                footerActionTitle: nil,
                footerActionHandler: nil,
                isEnabled: true
            )
        }

        return FeeOptionPresentation(
            description: nil,
            footerText: TKLocales.TronUsdtFees.TransactionConfirmation.noEnoughFunds,
            footerActionTitle: TKLocales.TronUsdtFees.TransactionConfirmation.refill,
            footerActionHandler: { [weak self] in
                self?.didRequestOpenFeeRefill?(extraType)
            },
            isEnabled: true
        )
    }

    private func isFeeOptionInsufficient(
        extraValue: TransactionConfirmationModel.ExtraValue?,
        walletBalance: KeeperCore.WalletBalance?
    ) -> Bool {
        guard let extraValue else {
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
            return tonBalance < amount

        case let .gasless(token, amount):
            if token.symbol?.uppercased() == TRX.symbol.uppercased() {
                let trxBalance = walletBalance.tronBalance?.trxAmount ?? 0
                return trxBalance < amount
            } else {
                return false
            }
        }
    }

    private func tronFeeBalanceAvailabilityText(
        transaction: TransactionConfirmationModel,
        feeDetails: TransactionConfirmationFeeCalculator.FeeDetails
    ) -> String? {
        guard case .transfer(.tronUSDT) = transaction.transaction else {
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
                    accessory: .symbol(TonInfo.symbol),
                    isNegative: false,
                    style: .compact
                )

            case .trx:
                let availableTRX = walletBalance.tronBalance?.trxAmount ?? 0
                availableText = amountFormatter.format(
                    amount: availableTRX,
                    fractionDigits: TRX.fractionDigits,
                    accessory: .symbol(TRX.symbol),
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
            !batteryBalance.isBalanceZero,
            let charges = batteryCalculation.calculateCharges(
                tonAmount: batteryBalance.balanceDecimalNumber
            )
        else {
            return 0
        }
        return charges
    }

    private func loadWalletBalance(wallet: Wallet, currency: Currency) async -> KeeperCore.WalletBalance? {
        if let cached = try? balanceService.getBalance(wallet: wallet) {
            return cached
        }
        return try? await balanceService.loadWalletBalance(
            wallet: wallet,
            currency: currency,
            includingTransferFees: true
        )
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
                state = .failed
                didFailTransaction?(model, error)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                state = .idle
            case .success:
                state = .success
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                NotificationCenter.default.postTransactionSendNotification(wallet: model.wallet)
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

private struct ChangellyDisclaimerPopUpItem: TKPopUp.Item {
    var bottomSpace: CGFloat

    func getView() -> UIView {
        let view = SendAssetDisclaimerView(verticalInsets: false)
        view.configure(model: .changelly)
        return view
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
