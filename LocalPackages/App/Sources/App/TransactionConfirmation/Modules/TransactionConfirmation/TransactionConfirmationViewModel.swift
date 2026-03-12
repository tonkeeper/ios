import BigInt
import KeeperCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import TronSwift
import UIKit

@MainActor
protocol TransactionConfirmationOutput: AnyObject {
    var didRequireSign: ((TransferData, Wallet) async throws -> SignedTransactions?)? { get set }
    var didStartConfirmTransaction: ((TransactionConfirmationModel) -> Void)? { get set }
    var didConfirmTransaction: ((TransactionConfirmationModel) -> Void)? { get set }
    var didFailTransaction: ((TransactionConfirmationModel, Error) -> Void)? { get set }
    var didProduceInsufficientFundsError: ((_ error: InsufficientFundsError) -> Void)? { get set }
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

    var didRequireSign: ((TransferData, Wallet) async throws -> SignedTransactions?)?
    var didStartConfirmTransaction: ((TransactionConfirmationModel) -> Void)?
    var didConfirmTransaction: ((TransactionConfirmationModel) -> Void)?
    var didFailTransaction: ((TransactionConfirmationModel, Error) -> Void)?
    var didProduceInsufficientFundsError: ((_ error: InsufficientFundsError) -> Void)?
    var didClose: (() -> Void)?
    var didRequestSendAllConfirmation: ((String, @escaping (Bool) -> Void) -> Void)?

    // MARK: - TransactionConfirmationViewModel

    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?

    func viewDidLoad() {
        confirmationController.signHandler = { [weak self] transferData, wallet in
            try await self?.didRequireSign?(transferData, wallet)
        }

        state = .processing
        update()
    }

    func didTapCloseButton() {
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

    private var updateTask: Task<Void, Never>?

    private var didChangePaymentMethod = false

    // MARK: - Dependencies

    private let confirmationController: TransactionConfirmationController
    private let amountFormatter: AmountFormatter
    private let fundsValidator: InsufficientFundsValidator
    private let currencyStore: CurrencyStore
    private let ratesService: RatesService
    private let configuration: Configuration

    // MARK: - Init

    init(
        confirmationController: TransactionConfirmationController,
        amountFormatter: AmountFormatter,
        fundsValidator: InsufficientFundsValidator,
        currencyStore: CurrencyStore,
        ratesService: RatesService,
        configuration: Configuration
    ) {
        self.confirmationController = confirmationController
        self.amountFormatter = amountFormatter
        self.fundsValidator = fundsValidator
        self.currencyStore = currencyStore
        self.ratesService = ratesService
        self.configuration = configuration
    }

    // MARK: - Private

    private func update() {
        self.updateTask?.cancel()
        self.updateTask = Task {
            self.state = .idle
            confirmationController.setLoading()
            let loadingModel = confirmationController.getModel()
            update(with: loadingModel)
            // TODO: сбрасывать текущий стейт, чтобы комиссия была со скелетоном
            let result = await confirmationController.emulate()
            if case let .failure(error) = result {
                handleError(error)
            }
            let model = confirmationController.getModel()
            let currency = currencyStore.state
            let rates = await getRates(model: model, currency: currency)
            guard !Task.isCancelled else { return }
            self.amountRate = rates.valueRate
            self.feeRate = rates.feeRate
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
            padding: UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16),
            items: [createListItem(transaction: model, amountRate: amountRate, feeRate: feeRate, currency: currency)]
        ))

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
        if let amountItem = createAmountItem(transaction: transaction, rate: amountRate, currency: currency) {
            items.append(amountItem)
        }
        if let apyItem = createAPYItem(transaction: transaction) {
            items.append(
                apyItem
            )
        }
        items.append(
            createFeeListItem(transaction: transaction, rate: feeRate, currency: currency)
        )
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
        case .failedToSendTransaction:
            text = "Failed to send transaction"
        case .failedToSign:
            text = "Failed to sign"
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
        let value = "\(String.almostEqual) \(apyPercents)%"
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
            isRefund = extra.kind == .refund
            extraType = extra.value.extraType

            var feeValueFormatted: String = ""
            var feeConvertedFormatted: String?
            func tokenFeeValueFormatted(amount: BigUInt, fractional: Int, symbol: String) -> (value: String, converted: String?) {
                let valueString = amountFormatter.format(
                    amount: amount,
                    fractionDigits: fractional,
                    accessory: .symbol(symbol)
                )

                var convertedString: String?
                if let rate {
                    let converted = RateConverter().convert(
                        amount: amount,
                        amountFractionLength: fractional,
                        rate: rate
                    )
                    let formatted = amountFormatter.format(
                        amount: converted.amount,
                        fractionDigits: converted.fractionLength,
                        accessory: .currency(currency),
                        isNegative: false,
                        style: .compact
                    )
                    convertedString = formatted
                }
                return (valueString, convertedString)
            }

            switch extra.value {
            case let .battery(charges, excess):
                if let charges {
                    feeValueFormatted = "\(charges) \(TKLocales.Battery.Refill.chargesCount(count: charges))"
                    if !isRefund, let excess {
                        feeConvertedFormatted = "\(String.almostEqual) \(excess) \(TKLocales.Battery.Refill.refunded(count: excess))"
                    }
                }
            case let .default(amount):
                (feeValueFormatted, feeConvertedFormatted) = tokenFeeValueFormatted(
                    amount: amount,
                    fractional: TonInfo.fractionDigits,
                    symbol: TonInfo.symbol
                )
            case let .gasless(token, amount):
                (feeValueFormatted, feeConvertedFormatted) = tokenFeeValueFormatted(
                    amount: amount,
                    fractional: token.fractionDigits,
                    symbol: token.symbol ?? token.name
                )
            }

            value = .value(TKListContainerItemDefaultValueView.Model(
                topValue: TKListContainerItemDefaultValueView.Model.Value(value: "\(String.almostEqual) \(feeValueFormatted)"),
                bottomValue: TKListContainerItemDefaultValueView.Model.Value(value: feeConvertedFormatted)
            ))

            if transaction.availableExtraTypes.count > 1 {
                let color: UIColor = didChangePaymentMethod ? .Text.tertiary : .Text.accent
                captionButton = TKPlainButton.Model(
                    title: TKLocales.TransactionConfirmation.changePaymentMethod.withTextStyle(.body2, color: color),
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
                            return TKImageView.Model(
                                image: .urlImage(token.imageURL),
                                tintColor: nil,
                                corners: .circle
                            )
                        }
                    }()

                    return TKPopupMenuItem(
                        title: title,
                        value: nil,
                        description: nil,
                        icon: nil,
                        leftIcon: leftIcon
                    ) { [weak self] in
                        self?.didChangePaymentMethod = true
                        self?.confirmationController.setPrefferedExtraType(extraType: item)
                        self?.update()
                    }
                }

                let selectedIndex = transaction.availableExtraTypes.firstIndex(of: extraType)

                TKPopupMenuController.show(
                    sourceView: view,
                    position: .topRight,
                    width: 0,
                    items: items,
                    selectedIndex: selectedIndex
                )
            }
        )
    }

    private func createActionBar(model: TransactionConfirmationModel) -> TKPopUp.Item {
        var items = [TKPopUp.Item]()

        if TKFeatureFlags.localProvider.isConfirmButtonInsteadSlider {
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
            Task { [weak self] in
                await self?.confirmAction(model: model)
            }
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
                Task { [weak self] in
                    await self?.confirmAction(model: model)
                }
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
    ) async -> (valueRate: Rates.Rate?, feeRate: Rates.Rate?) {
        enum Token {
            case ton
            case jetton(JettonInfo)
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
            case let .gasless(token, _): feeToken = .jetton(token)
            case .battery: feeToken = .none
            }
        }

        let jettons: [JettonInfo] = [valueToken, feeToken].compactMap { token -> JettonInfo? in
            switch token {
            case .ton:
                return nil
            case let .jetton(jettonInfo):
                return jettonInfo
            case nil:
                return nil
            }
        }

        do {
            let rates = try await ratesService.loadRates(jettons: jettons.map { $0.address.toRaw() }, currencies: [currency])

            let valueRate: Rates.Rate?
            switch valueToken {
            case .ton:
                valueRate = rates.ton.first(where: { $0.currency == currency })
            case let .jetton(jettonInfo):
                valueRate = rates.jettonRates.first(where: { $0.key == jettonInfo.address.toRaw() })?
                    .value
                    .first(where: { $0.currency == currency })
            case nil:
                valueRate = nil
            }

            let feeRate: Rates.Rate?
            switch feeToken {
            case .ton:
                feeRate = rates.ton.first(where: { $0.currency == currency })
            case let .jetton(jettonInfo):
                feeRate = rates.jettonRates.first(where: { $0.key == jettonInfo.address.toRaw() })?
                    .value
                    .first(where: { $0.currency == currency })
            case .none:
                feeRate = nil
            }

            return (valueRate, feeRate)
        } catch {
            return (nil, nil)
        }
    }

    private func confirmAction(model: TransactionConfirmationModel) async {
        didStartConfirmTransaction?(model)
        if model.isMaxAmountUsed {
            let tokenName = model.amount?.token.symbol ?? "Token"
            let confirmed = await withCheckedContinuation { continuation in
                didRequestSendAllConfirmation?(tokenName) { confirmed in
                    continuation.resume(returning: confirmed)
                }
            }
            guard confirmed else {
                self.state = .idle
                return
            }
        }
        self.state = .processing

        do {
            try await fundsValidator.validateFundsIfNeeded(wallet: model.wallet, emulationModel: model)

            let result = await self.confirmationController.sendTransaction()
            switch result {
            case .success:
                self.state = .success
                try await Task.sleep(nanoseconds: 1_000_000_000)
                NotificationCenter.default.postTransactionSendNotification(wallet: model.wallet)
                didConfirmTransaction?(model)
            case let .failure(error):
                handleError(error)
                self.state = .failed
                didFailTransaction?(model, error)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self.state = .idle
            }
        } catch {
            self.state = .failed
            didFailTransaction?(model, error)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.state = .idle

            if let error = error as? InsufficientFundsError {
                didProduceInsufficientFundsError?(error)
            }
        }
    }
}

private extension String {
    static let almostEqual = "\u{2248}"
}
