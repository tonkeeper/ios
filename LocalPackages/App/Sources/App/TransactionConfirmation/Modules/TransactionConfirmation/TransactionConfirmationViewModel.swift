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
    var didClose: (() -> Void)? { get set }

    func refresh()
}

@MainActor
protocol TransactionConfirmationViewModel: AnyObject {
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
    var didOpenFeePicker: ((NetworkFeePickerPresentation) -> Void)?
    var didStartConfirmTransaction: ((TransactionConfirmationModel) -> Void)?
    var didConfirmTransaction: ((TransactionConfirmationModel) -> Void)?
    var didFailTransaction: ((TransactionConfirmationModel, any AnalyticsError) -> Void)?
    var didCancelTransaction: (() -> Void)?
    var didProduceInsufficientFundsError: ((_ error: InsufficientFundsError) -> Void)?
    var didRequestOpenFeeRefill: ((_ extraType: TransactionConfirmationModel.ExtraType) -> Void)?
    var didDetectInsufficientMultichainFee: ((MultichainNativeFeeShortage) -> Void)?
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

    func refresh() {
        update()
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
            reportInsufficientMultichainFeeIfNeeded(model)
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

        if withdrawDisplayInfo == nil {
            let caption: String = {
                switch model.transaction {
                case .staking:
                    return TKLocales.TransactionConfirmation.confirmAction
                case let .transfer(transfer):
                    switch transfer {
                    case .jetton, .ton, .tronUSDT, .tronTRX, .multichain:
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
        }
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

    private func reportInsufficientMultichainFeeIfNeeded(_ model: TransactionConfirmationModel) {
        guard model.isSelectedFeeInsufficient,
              case .transfer(.multichain) = model.transaction,
              case let .extra(extra) = model.extraState,
              case let .multichain(asset, amount) = extra.value
        else {
            return
        }
        didDetectInsufficientMultichainFee?(
            MultichainNativeFeeShortage(
                asset: asset,
                requiredAmount: amount
            )
        )
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
                case .tronTRX:
                    return "Transfer \(TronSwift.TRX.name)"
                case let .multichain(asset):
                    return "Transfer \(asset.asset.symbol)"
                }
            }
        }()
        let attributedText = NSMutableAttributedString(
            attributedString: text.withTextStyle(
                .h3,
                color: .Text.primary,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
        )

        if withdrawDisplayInfo == nil,
           case let .transfer(.multichain(asset)) = transaction,
           !asset.isNative,
           let chain = asset.asset.chain
        {
            attributedText.append(
                " \(chain.shortDisplayTitle)".withTextStyle(
                    .h3,
                    color: .Text.secondary,
                    alignment: .center,
                    lineBreakMode: .byTruncatingTail
                )
            )
        }

        return TKPopUp.Component.LabelComponent(
            text: attributedText,
            numberOfLines: 1,
            bottomSpace: 0
        )
    }

    private func createHeaderImageItem(transaction: TransactionConfirmationModel) -> TKPopUp.Item {
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
            return WithdrawTransactionConfirmationExchangeHeaderItem(model: exchangeModel, bottomSpace: 32)
        }

        let image: TKImage
        let corners: TKImageView.Corners
        let badgeImage: TKImage?

        switch transaction.transaction {
        case let .staking(staking):
            image = .image(staking.pool.bigIcon)
            badgeImage = nil
            corners = .circle
        case let .transfer(transfer):
            switch transfer {
            case let .jetton(jettonInfo):
                image = .urlImage(jettonInfo.imageURL)
                badgeImage = transaction.wallet.tron != nil && jettonInfo.isTonUSDT ? .image(.TKUIKit.Icons.Size44.tonChain) : nil
                corners = .circle
            case .ton:
                image = .image(.TKUIKit.Icons.Size44.currencyTon)
                badgeImage = nil
                corners = .circle
            case let .nft(nft):
                image = .urlImage(nft.imageURL)
                badgeImage = nil
                corners = .cornerRadius(cornerRadius: 12)
            case .tronUSDT:
                image = .image(.TKUIKit.Icons.Size96.currencyUsdt)
                badgeImage = .image(.TKUIKit.Icons.Size44.currencyTrc20)
                corners = .circle
            case .tronTRX:
                image = .image(.TKUIKit.Icons.Size44.trxChain)
                badgeImage = nil
                corners = .circle
            case let .multichain(asset):
                let source = AssetIdResolver.tkImageSource(
                    for: asset.asset.assetId,
                    imageUrl: URL(string: asset.asset.image),
                    multichainEnabled: true
                )
                image = source.image
                badgeImage = source.chainIcon.map(TKImage.image)
                corners = .circle
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
        if let assetChainItem = createAssetChainItem(transaction: transaction) {
            items.append(assetChainItem)
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
        case let .multichainTransactionFailure(failure):
            text = failure.transactionConfirmationUserMessage
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
        return TKListContainerItemView.Model(
            title: TKLocales.TransactionConfirmation.recipient,
            value: .value(
                TKListContainerItemDefaultValueView.Model(
                    topValue: TKListContainerItemDefaultValueView.Model.Value(value: recipientAddress.shortenedMiddle())
                )
            ),
            action: .custom { view in
                MainActor.assumeIsolated {
                    Self.toggleAddressTooltip(value: recipientAddress, sourceView: view)
                }
            }
        )
    }

    @MainActor
    private static func toggleAddressTooltip(value: String, sourceView: UIView) {
        let maximumWidth: CGFloat = 260
        HintController.toggle(
            sourceView: sourceView,
            configuration: HintConfiguration(
                position: HintPosition(
                    tailParameters: TKTooltipView.tailParameters,
                    horizontal: .default,
                    vertical: .init(absolute: 0),
                    direction: .topCenter
                ),
                maximumWidth: maximumWidth,
                animationStyle: .bouncing
            ),
            contentViewControllerProvider: { direction in
                let rootView = TKTooltipView(
                    configuration: TKTooltipView.Configuration(title: value, lineLimit: nil),
                    position: direction
                )
                let hostingController = TKHostingController(content: rootView)
                hostingController.view.backgroundColor = .clear
                let size = hostingController.sizeThatFits(
                    in: CGSize(width: maximumWidth, height: .greatestFiniteMagnitude)
                )
                hostingController.preferredContentSize = CGSize(
                    width: min(maximumWidth, ceil(size.width)),
                    height: ceil(size.height)
                )
                return hostingController
            }
        )
    }

    private func createAssetChainItem(transaction: TransactionConfirmationModel) -> TKListContainerItem? {
        guard case let .transfer(.multichain(asset)) = transaction.transaction,
              let chain = asset.asset.chain
        else {
            return nil
        }

        return TKListContainerItemView.Model(
            title: TKLocales.Ramp.Deposit.network,
            value: .value(
                TKListContainerItemDefaultValueView.Model(
                    topValue: TKListContainerItemDefaultValueView.Model.Value(value: chain.addressConfiguration.title),
                    bottomValue: TKListContainerItemDefaultValueView.Model.Value(value: chain.tokenType)
                )
            ),
            action: nil
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
            accessory: .tokenSymbol(info.symbol, onLeft: false),
            style: .compact
        )
        let topValue = "\(TKLocales.Common.Numbers.approximate) \(topFormatted)"

        let bottomFormatted: String
        if let usdtFiatRate {
            let converted = feeDecimal * usdtFiatRate.rate
            bottomFormatted = amountFormatter.format(
                decimal: converted,
                accessory: .fiat(currency),
                style: .compact
            )
        } else {
            bottomFormatted = amountFormatter.format(
                decimal: feeDecimal,
                accessory: .fiat(Currency.USD),
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
            style: .percent
        )
        let value = "\(TKLocales.Common.Numbers.approximate) \(apyPercents)"
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
            case .jetton, .ton, .tronUSDT, .tronTRX, .multichain:
                title = TKLocales.TransactionConfirmation.amount
            case .nft:
                return nil
            }
        }

        guard let amount = transaction.amount else { return nil }

        if case let .multichain(asset) = amount.token {
            let valueFormatted = amountFormatter.format(
                amount: amount.value,
                fractionDigits: asset.asset.decimals,
                accessory: .tokenSymbol(asset.asset.symbol),
                isNegative: false,
                style: .exactValue
            )

            return TKListContainerItemView.Model(
                title: title,
                value: .value(TKListContainerItemDefaultValueView.Model(
                    topValue: TKListContainerItemDefaultValueView.Model.Value(value: valueFormatted),
                    bottomValue: TKListContainerItemDefaultValueView.Model.Value(
                        value: multichainConvertedAmount(
                            amount: amount.value,
                            asset: asset,
                            currency: currency
                        )
                    )
                )),
                action: .copy(copyValue: valueFormatted)
            )
        }

        let value: TKListContainerItemView.Model.Value
        let valueFormatted = amountFormatter.format(
            amount: amount.value,
            fractionDigits: amount.token.fractionDigits,
            accessory: .tokenSymbol(amount.token.symbol),
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
                accessory: .fiat(currency)
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
        var isRefund: Bool = false
        let value: TKListContainerItemView.Model.Value
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
            let usesNetworkFeePicker = canOpenFeePicker

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

            if usesNetworkFeePicker {
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
                value = .value(
                    TransactionConfirmationNetworkFeeValueView.Configuration(
                        primaryText: primaryText,
                        tokenSymbol: tokenSymbol,
                        showsPicker: canOpenFeePicker
                    )
                )
            } else {
                value = .value(TKListContainerItemDefaultValueView.Model(
                    topValue: TKListContainerItemDefaultValueView.Model.Value(value: "\(TKLocales.Common.Numbers.approximate) \(feeFormatted.topValue)"),
                    bottomValue: TKListContainerItemDefaultValueView.Model.Value(
                        value: tronFeeBalanceAvailability ?? feeFormatted.bottomValue
                    )
                ))
            }

        case .none:
            value = .value(
                TransactionConfirmationFeeErrorValueView.Configuration(
                    retry: { [weak self] in
                        self?.update()
                    }
                )
            )
        }
        return TKListContainerItemView.Model(
            title: isRefund
                ? TKLocales.EventDetails.refund
                : feeTitle(transaction: transaction),
            captionButtonModel: nil,
            value: value,
            action: .custom { [weak self] _ in
                guard canOpenFeePicker, let self else { return }

                let presentation = self.makeFeePickerPresentation(
                    currency: currency,
                    tonRate: tonRate,
                    trxRate: trxRate,
                    title: isRefund
                        ? TKLocales.EventDetails.refund
                        : TKLocales.FeeMethodPicker.title,
                    subtitle: isRefund
                        ? nil
                        : TKLocales.FeeMethodPicker.subtitle,
                    skeletonItemCount: transaction.networkFeePickerSkeletonItemCount
                )

                self.didOpenFeePicker?(presentation)
            }
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
                        return TKLocales.TransactionConfirmation.Buttons.confirmAndCollect
                    } else {
                        return TKLocales.TransactionConfirmation.Buttons.confirmAndUnstake
                    }
                }
            case .transfer:
                return TKLocales.TransactionConfirmation.Buttons.confirmAndSend
            }
        }()
        var btnConf = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        btnConf.content = .init(title: .plainString(buttonTitle))
        btnConf.isEnabled = isConfirmEnabled(transaction: model)
        btnConf.action = { [weak self] in
            self?.confirmAction(model: model)
        }

        return TKPopUp.Component.ButtonGroupComponent(buttons: [
            TKPopUp.Component.ButtonComponent(buttonConfiguration: btnConf),
        ])
    }

    private func createConfirmSlider(model: TransactionConfirmationModel) -> TKPopUp.Item {
        let sliderTitle = NSMutableAttributedString()
        sliderTitle.append(TKLocales.Actions.Confirm.title.withTextStyle(.label1, color: .Text.tertiary, alignment: .center))
        sliderTitle.append("\n".withTextStyle(.body2, color: .Text.tertiary, alignment: .center))
        sliderTitle.append(TKLocales.Actions.Confirm.subtitle.withTextStyle(.body2, color: .Text.tertiary, alignment: .center))
        let sliderItem = TKPopUp.Component.Slider(
            title: sliderTitle,
            isEnable: isConfirmEnabled(transaction: model),
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

private struct WithdrawTransactionConfirmationExchangeHeaderItem: TKPopUp.Item {
    let model: SendAssetExchangeView.Model
    let bottomSpace: CGFloat

    func getView() -> UIView {
        let exchangeView = SendAssetExchangeView()
        exchangeView.configure(model: model)

        let container = UIView()
        container.addSubview(exchangeView)
        exchangeView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.right.equalToSuperview().inset(32)
        }
        return container
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
