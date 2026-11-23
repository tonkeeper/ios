import AppUI
import BigInt
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKLogging
import TKUIKit

protocol BatteryRefillModuleOutput: AnyObject {
    var didTapSupportedTransactions: ((BatteryNetworks) -> Void)? { get set }
    var didTapRecharge: ((_ rechargeMethod: BatteryRefillRechargeMethodsModel.RechargeMethodItem) -> Void)? { get set }
    var didTapAssetRecharge: ((BatteryRechargeAsset, BigUInt?, String?) -> Void)? { get set }
    var didTapContinue: ((BatteryRechargePayload) -> Void)? { get set }
    var didTapPayWith: ((_ methods: [BatteryRefillViewState.PaymentMethod], _ select: @escaping (String) -> Void) -> Void)? { get set }
    var didOpenRefundURL: ((_ url: URL, _ title: String) -> Void)? { get set }
    var didFinish: (() -> Void)? { get set }
}

protocol BatteryRefillModuleInput: AnyObject {
    func refresh()
    @MainActor func loadRechargeOptions(selectedID: String) async -> [BatteryRechargeOption]
    func selectPaymentMethod(id: String)
}

struct BatteryRechargeOption {
    enum Destination {
        case crypto(BatteryRefillRechargeMethodsModel.RechargeMethodItem)
        case appStore
    }

    let destination: Destination
    let presentation: BatteryRefillViewState.PaymentMethod
}

final class BatteryRefillViewModelImplementation: ObservableObject, BatteryRefillModuleOutput, BatteryRefillModuleInput {
    /// Keeps the pack picked before while it can be bought, or while none can (a purchase in progress
    /// disables them all); else the middle one, as the design opens with, else the first that can be bought.
    /// Other stays picked while the method offers it, also while it cannot buy for a moment.
    static func packId(previous: String?, enabledIds: [String], allowsCustom: Bool = false) -> String? {
        if allowsCustom, previous == customPackId { return previous }
        guard !enabledIds.isEmpty else { return previous }
        if let previous, enabledIds.contains(previous) {
            return previous
        }
        return enabledIds.count > 1 ? enabledIds[enabledIds.count / 2] : enabledIds.first
    }

    // MARK: - BatteryRefillModuleOutput

    var didTapSupportedTransactions: ((BatteryNetworks) -> Void)?
    var didTapRecharge: ((_ rechargeMethod: BatteryRefillRechargeMethodsModel.RechargeMethodItem) -> Void)?
    var didTapAssetRecharge: ((BatteryRechargeAsset, BigUInt?, String?) -> Void)?
    var didTapContinue: ((BatteryRechargePayload) -> Void)?
    var didTapPayWith: ((_ methods: [BatteryRefillViewState.PaymentMethod], _ select: @escaping (String) -> Void) -> Void)?
    var didOpenRefundURL: ((_ url: URL, _ title: String) -> Void)?
    var didFinish: (() -> Void)?

    // MARK: - State

    typealias AmountField = BatteryAmountInputView.Field

    @Published private(set) var state = BatteryRefillViewState()
    let amountInputViewModel: AmountInputSwiftUIViewModel

    var amountField: AmountField {
        let isSecureMode = appSettingsStore.getState().isSecureMode
        switch selectedMethod {
        case let .asset(asset):
            let charges = BatteryRechargeMath.value(customAmount, decimals: asset.method.decimals)
                .flatMap { value in asset.rate.map { BatteryRechargeMath.charges(amount: value, rate: $0) } }
            return AmountField(
                placeholder: TKLocales.Battery.Refill.amountPlaceholder(asset.method.symbol),
                charges: customChargesCaption(charges),
                available: TKLocales.Battery.Refill.amountAvailable(isSecureMode
                    ? String.secureModeValueShort
                    : amountFormatter.format(amount: asset.asset.balance, fractionDigits: asset.method.decimals, accessory: .tokenSymbol(asset.method.symbol), style: .compact))
            )
        case let .token(token):
            let charges = rechargeModel.map {
                BatteryRechargeModel.chargesCount(amount: customAmount, fractionDigits: token.fractionDigits, tonChargeRate: $0.tonChargeRate)
            }
            return AmountField(
                placeholder: TKLocales.Battery.Refill.amountPlaceholder(token.symbol),
                charges: customChargesCaption(charges),
                available: TKLocales.Battery.Refill.amountAvailable(isSecureMode
                    ? String.secureModeValueShort
                    : amountFormatter.format(amount: balance(token: token), fractionDigits: token.fractionDigits, accessory: .tokenSymbol(token.symbol), style: .compact))
            )
        case .appStore, nil:
            return AmountField(placeholder: "", charges: nil, available: nil)
        }
    }

    var showsCloseButton = false {
        didSet { updateState() }
    }

    var didTapClose: (() -> Void)?
    var endEditing: (() -> Void)?
    var endPromocodeEditing: (() -> Void)?

    lazy var actions = BatteryRefillViewActions(
        selectPack: { [weak self] in self?.selectPack(id: $0) },
        choosePaymentMethod: { [weak self] in self?.choosePaymentMethod() },
        confirm: { [weak self] in self?.confirm() },
        openLink: { [weak self] in self?.openLink($0) },
        openSupportedTransactions: { [weak self] in self?.openSupportedTransactions() },
        restorePurchases: { [weak self] in self?.restorePurchases() },
        close: { [weak self] in self?.didTapClose?() },
        endEditing: { [weak self] in self?.endEditing?() }
    )

    private var header: BatteryRefillViewState.Header?
    private var networks = BatteryNetworks.tonAndTron
    private var inAppPurchaseItems = [BatteryIAPItem]()
    private var rechargeMethodItems = [BatteryRefillRechargeMethodsModel.RechargeMethodItem]()
    private var selectedMethodId: String?
    private var selectedPackIds = [String: String]()
    private var rechargeModel: BatteryRechargeModel?
    private var customAmount: BigUInt = 0
    private var amountInputMethodId: String?
    private let multichainFormatter = MultichainPortfolioAmountFormatting()
    private var promocode: String? {
        didSet {
            inAppPurchaseModel.promocode = promocode
        }
    }

    // MARK: - Dependencies

    private let wallet: Wallet
    private let inAppPurchaseModel: BatteryRefillIAPModel
    private let rechargeMethodsModel: BatteryRefillRechargeMethodsModel
    private let headerModel: BatteryRefillHeaderModel
    private let makeRechargeModel: (TonToken) -> BatteryRechargeModel
    private let currencyStore: CurrencyStore
    private let balanceStore: BalanceStore
    private let appSettingsStore: AppSettingsStore
    private let tonProofTokenService: TonProofTokenService
    private let configuration: Configuration
    private let amountFormatter: AmountFormatter
    private let promocodeOutput: BatteryPromocodeInputModuleOutput
    private let analytics: BatteryAnalytics
    private let relayedEVMChains: @Sendable () async -> Set<MultichainChain>?
    private let batteryCalculation: BatteryCalculation
    private let userDefaults: UserDefaults

    // MARK: - Init

    init(
        wallet: Wallet,
        inAppPurchaseModel: BatteryRefillIAPModel,
        rechargeMethodsModel: BatteryRefillRechargeMethodsModel,
        headerModel: BatteryRefillHeaderModel,
        makeRechargeModel: @escaping (TonToken) -> BatteryRechargeModel,
        balanceStore: BalanceStore,
        currencyStore: CurrencyStore,
        appSettingsStore: AppSettingsStore,
        tonProofTokenService: TonProofTokenService,
        configuration: Configuration,
        amountFormatter: AmountFormatter,
        promocodeOutput: BatteryPromocodeInputModuleOutput,
        analytics: BatteryAnalytics,
        relayedEVMChains: @escaping @Sendable () async -> Set<MultichainChain>?,
        batteryCalculation: BatteryCalculation,
        userDefaults: UserDefaults = .standard
    ) {
        self.wallet = wallet
        self.inAppPurchaseModel = inAppPurchaseModel
        self.rechargeMethodsModel = rechargeMethodsModel
        self.headerModel = headerModel
        self.makeRechargeModel = makeRechargeModel
        self.balanceStore = balanceStore
        self.currencyStore = currencyStore
        self.appSettingsStore = appSettingsStore
        self.tonProofTokenService = tonProofTokenService
        self.configuration = configuration
        self.amountFormatter = amountFormatter
        self.promocodeOutput = promocodeOutput
        self.analytics = analytics
        self.relayedEVMChains = relayedEVMChains
        self.batteryCalculation = batteryCalculation
        self.userDefaults = userDefaults
        amountInputViewModel = AmountInputSwiftUIViewModel(amountFormatter: amountFormatter, sourceUnit: TonToken.ton, destinationUnit: ChargeItem())
        selectedMethodId = userDefaults.string(forKey: selectedMethodKey)
    }

    func refresh() {
        rechargeMethodsModel.loadMethods()
    }

    func viewDidLoad() {
        setupPromocode()
        amountInputViewModel.didUpdateSourceAmount = { [weak self] in self?.updateCustomAmount($0) }
        headerModel.didUpdateState = { [weak self] state in
            self?.updateHeader(state: state)
        }
        updateHeader(state: headerModel.getState())
        loadNetworks()

        inAppPurchaseItems = inAppPurchaseModel.items
        inAppPurchaseModel.loadProducts()
        inAppPurchaseModel.loadPurchasesAvailability()
        inAppPurchaseModel.eventHandler = { [weak self] event in
            switch event {
            case let .didUpdateItems(items):
                self?.inAppPurchaseItems = items
                self?.updatePaymentMethod()
            case let .didPerformTransaction(purchase):
                if let purchase {
                    self?.analytics.logSuccess(purchase)
                }
                ToastPresenter.showToast(configuration: .defaultConfiguration(text: TKLocales.Battery.Refill.Toast.recharged))
            case let .didFailTransaction(error: error):
                Log.e("battery refill didFailTransaction", extraInfo: [
                    "error": error?.localizedDescription ?? "unknown error",
                ])
            }
        }

        updateRechargeMethods(state: rechargeMethodsModel.state)
        rechargeMethodsModel.stateHandler = { [weak self] state in
            self?.updateRechargeMethods(state: state)
        }
        rechargeMethodsModel.loadMethods()
    }

    // MARK: - Actions

    private func selectPack(id: String) {
        endPromocodeEditing?()
        guard let method = selectedMethod else { return }
        guard id != Self.customPackId else {
            selectCustomAmount(method: method)
            return
        }
        switch method {
        case let .asset(asset):
            guard let pack = asset.packages.first(where: { $0.id == id }), let amount = asset.amount(for: pack), asset.canBuy(amount) else { return }
        case .appStore:
            guard inAppPurchaseItems.contains(where: { $0.pack.productIdentifier == id && $0.isEnable }) else { return }
        case .token:
            guard rechargeModel?.optionsItems.contains(where: { $0.identifier == id && $0.isEnable }) == true else { return }
        }
        guard selectedPackIds[method.id] != id else {
            confirm()
            return
        }
        selectedPackIds[method.id] = id
        updateState()
    }

    /// A tap on Other opens the amount field; a second tap does not buy, unlike a pack.
    private func selectCustomAmount(method: Method) {
        guard selectedPackIds[method.id] != Self.customPackId else { return }
        switch method {
        case let .asset(asset):
            guard asset.isReady else { return }
        case .appStore:
            return
        case .token:
            guard let rechargeModel else { return }
            rechargeModel.selectedOptionItem = .custom
        }
        selectedPackIds[method.id] = Self.customPackId
        amountInputViewModel.reset()
        amountInputViewModel.requestFocus()
        updateState()
    }

    private func updateCustomAmount(_ amount: BigUInt) {
        customAmount = amount
        if case .token = selectedMethod {
            rechargeModel?.amount = amount
        }
        updateState()
    }

    private func choosePaymentMethod() {
        endPromocodeEditing?()
        let selectedId = selectedMethod?.id
        let rows = payWithRows(paymentMethods, selectedId: selectedId).map(\.row)
        didTapPayWith?(rows) { [weak self] id in
            guard let self else { return }
            let opensCharge = rows.first(where: { $0.id == id })?.otherToken != nil
            if opensCharge, case let .asset(asset)? = rechargeMethodItems.first(where: { $0.identifier == id }), !asset.isReady { return }
            selectPaymentMethod(id: id)
            guard opensCharge,
                  selectedMethod?.id == id,
                  let item = rechargeMethodItems.first(where: { $0.identifier == id })
            else { return }
            didTapRecharge?(item)
        }
    }

    func selectPaymentMethod(id: String) {
        guard paymentMethods.contains(where: { $0.id == id }) else { return }
        selectedMethodId = id
        userDefaults.set(id, forKey: selectedMethodKey)
        updatePaymentMethod()
    }

    @MainActor
    func loadRechargeOptions(selectedID: String) async -> [BatteryRechargeOption] {
        let items = await rechargeMethodsModel.loadedItems()
        var destinations = [String: BatteryRechargeOption.Destination]()
        var methods = items.compactMap { item -> Method? in
            let method: Method
            switch item {
            case let .token(token): method = .token(token)
            case let .asset(asset): method = .asset(asset)
            case .gift: return nil
            }
            destinations[method.id] = .crypto(item)
            return method
        }
        if !inAppPurchaseItems.isEmpty {
            methods.append(.appStore)
            destinations[Method.appStoreId] = .appStore
        }
        return payWithRows(methods, selectedId: selectedID).compactMap { method, row in
            destinations[method.id].map { BatteryRechargeOption(destination: $0, presentation: row) }
        }
    }

    private func confirm() {
        endPromocodeEditing?()
        endEditing?()
        guard let method = selectedMethod, let packId = selectedPackIds[method.id] else { return }
        if packId == Self.customPackId {
            confirmCustomAmount(method: method)
            return
        }
        switch method {
        case let .asset(asset):
            guard let pack = asset.packages.first(where: { $0.id == packId }), let amount = asset.amount(for: pack), asset.canBuy(amount) else { return }
            didTapAssetRecharge?(asset, amount, promocode)
        case .appStore:
            guard inAppPurchaseModel.startProcessing(identifier: packId),
                  let pack = BatteryIAPPack(rawValue: packId) else { return }
            analytics.logSelect(.fiat(pack: pack, promocode: promocode))
        case .token:
            guard let rechargeModel,
                  let option = rechargeModel.optionsItems.first(where: { $0.identifier == packId && $0.isEnable })
            else { return }
            rechargeModel.selectedOptionItem = option
            rechargeModel.promocode = promocode
            didTapContinue?(rechargeModel.getConfirmationPayload())
        }
    }

    private func confirmCustomAmount(method: Method) {
        guard isCustomAmountValid(method: method) else { return }
        switch method {
        case let .asset(asset):
            didTapAssetRecharge?(asset, customAmount, promocode)
        case .appStore:
            return
        case .token:
            guard let rechargeModel else { return }
            rechargeModel.selectedOptionItem = .custom
            rechargeModel.amount = customAmount
            rechargeModel.promocode = promocode
            didTapContinue?(rechargeModel.getConfirmationPayload())
        }
    }

    private func openLink(_ link: BatteryRefillViewState.Link) {
        endPromocodeEditing?()
        switch link {
        case .gift:
            guard let gift = rechargeMethodItems.first(where: { if case .gift = $0 { true } else { false } }) else { return }
            didTapRecharge?(gift)
        case .history:
            guard let url = createRefundURL() else { return }
            didOpenRefundURL?(url, TKLocales.Battery.Refill.ChargesHistory.title)
        }
    }

    private func openSupportedTransactions() {
        didTapSupportedTransactions?(networks)
    }

    private func restorePurchases() {
        ToastPresenter.showToast(configuration: .loading)
        Task { @MainActor [weak self] in
            guard let self else {
                ToastPresenter.hideAll()
                return
            }
            let result = await self.inAppPurchaseModel.restorePurchases()
            ToastPresenter.hideAll()
            switch result {
            case .success:
                ToastPresenter.showToast(configuration: ToastPresenter.Configuration(title: TKLocales.RestorePurchases.restored))
            case let .failure(error):
                switch error {
                case .nothingToRestore:
                    ToastPresenter.showToast(configuration: ToastPresenter.Configuration(title: TKLocales.RestorePurchases.nothingToRestore))
                default:
                    ToastPresenter.showToast(configuration: ToastPresenter.Configuration(title: TKLocales.RestorePurchases.failed(error.rawValue)))
                }
            }
        }
    }
}

// MARK: - Payment methods

private extension BatteryRefillViewModelImplementation {
    enum Method {
        case asset(BatteryRechargeAsset)
        case appStore
        case token(TonToken)

        static let appStoreId = "app_store"

        var payWithKind: BatteryPayWithOrder.Kind {
            switch self {
            case let .asset(asset):
                if BatteryPayWithOrder.isTronUSDT(assetId: asset.method.assetId) {
                    .tronUSDT
                } else if BatteryPayWithOrder.isEthereumUSDT(assetId: asset.method.assetId) {
                    .ethereumUSDT
                } else {
                    .other
                }
            case .appStore: .appStore
            case .token(.ton): .gram
            case let .token(.jetton(jettonItem)): jettonItem.jettonInfo.isTonUSDT ? .tonUSDT : .other
            }
        }

        var id: String {
            switch self {
            case let .asset(asset): asset.method.assetId
            case .appStore: Self.appStoreId
            case let .token(token): token.identifier
            }
        }
    }

    static let customPackId = BatteryRechargeModel.OptionItem.custom.identifier

    var selectedMethodKey: String {
        "battery_refill_payment_method_\(wallet.id)"
    }

    var showsRefill: Bool {
        !configuration.flag(\.batteryDisabled, network: wallet.network)
    }

    /// The tokens first, then the App Store, as the design orders them.
    var paymentMethods: [Method] {
        let tokens: [Method] = rechargeMethodItems.compactMap {
            switch $0 {
            case let .token(token): .token(token)
            case let .asset(asset): .asset(asset)
            case .gift: nil
            }
        }
        return tokens + (inAppPurchaseItems.isEmpty ? [] : [.appStore])
    }

    /// The method picked last on this wallet while it is still offered; else the App Store, else the first token.
    var selectedMethod: Method? {
        let methods = paymentMethods
        if let saved = methods.first(where: { $0.id == selectedMethodId }) {
            return saved
        }
        // A saved token is offered only once the methods load: falling back meanwhile would offer another method.
        if selectedMethodId != nil, case .loading = rechargeMethodsModel.state {
            return nil
        }
        return methods.first { if case .appStore = $0 { true } else { false } }
            ?? methods.first
    }

    /// The Pay with list: the leading methods and the selected one, then the rest under Other tokens, the largest
    /// holdings first.
    func payWithRows(_ methods: [Method], selectedId: String?) -> [(method: Method, row: BatteryRefillViewState.PaymentMethod)] {
        var (featured, other) = BatteryPayWithOrder.split(methods, kind: \.payWithKind)
        if let index = other.firstIndex(where: { $0.id == selectedId }) {
            featured.append(other.remove(at: index))
        }
        let currency = currencyStore.getState()
        let isSecureMode = appSettingsStore.getState().isSecureMode
        let featuredRows = featured.map { ($0, paymentMethod($0, isSelected: $0.id == selectedId)) }
        let otherRows = other
            .map { method in (method: method, fiat: fiatValue(method, currency: currency)) }
            .enumerated()
            .sorted { ($0.element.fiat ?? 0, -$0.offset) > ($1.element.fiat ?? 0, -$1.offset) }
            .map { _, item in
                let row = paymentMethod(item.method, isSelected: item.method.id == selectedId)
                let otherToken = otherToken(item.method, currency: currency, isSecureMode: isSecureMode)
                return (item.method, BatteryRefillViewState.PaymentMethod(
                    id: row.id, icon: row.icon, name: row.name, caption: row.caption, isSelected: row.isSelected, otherToken: otherToken
                ))
            }
        return featuredRows + otherRows
    }

    func fiatValue(_ method: Method, currency: Currency) -> Decimal? {
        switch method {
        case let .asset(asset):
            return multichainFormatter.convertedAmount(for: asset.asset, currency: currency)
        case let .token(.jetton(jettonItem)):
            guard let jettonBalance = jettonBalance(jettonItem), let rate = jettonBalance.rates[currency]?.rate else { return nil }
            return multichainFormatter.decimalAmount(amount: jettonBalance.quantity, fractionDigits: jettonItem.jettonInfo.fractionDigits) * rate
        case .token(.ton), .appStore:
            return nil
        }
    }

    func otherToken(_ method: Method, currency: Currency, isSecureMode: Bool) -> BatteryRefillViewState.PaymentMethod.OtherToken? {
        let chain: MultichainChain
        let symbol: String
        let badge: String?
        let imageSource: AssetAvatarViewImageSource
        let unitPrice: Decimal?
        let balance: String
        switch method {
        case let .asset(asset):
            guard let assetChain = asset.method.chain else { return nil }
            chain = assetChain
            symbol = asset.method.symbol
            badge = AssetIdResolver.tag(for: asset.asset.asset.assetId, multichainEnabled: true)
            imageSource = AssetIdResolver.imageSource(for: asset.method.assetId, imageUrl: asset.method.imageURL, multichainEnabled: true)
            unitPrice = multichainFormatter.lookupDouble(in: asset.asset.price.prices, currency: currency).map { Decimal($0) }
            balance = multichainFormatter.formatAmount(amount: asset.asset.balance, fractionDigits: asset.method.decimals, amountFormatter: amountFormatter)
        case let .token(token):
            chain = .ton
            symbol = token.symbol
            switch token {
            case .ton:
                badge = nil
                imageSource = .image(.TKUIKit.Icons.Size44.tonLogo)
                unitPrice = nil
            case let .jetton(jettonItem):
                badge = tonNetwork?.badgeTitle
                imageSource = .url(jettonItem.jettonInfo.imageURL, chainIcon: tonNetwork?.tokenIcon20)
                unitPrice = jettonBalance(jettonItem)?.rates[currency]?.rate
            }
            balance = amountFormatter.format(amount: self.balance(token: token), fractionDigits: token.fractionDigits, style: .compact)
        case .appStore:
            return nil
        }
        let fiat = fiatValue(method, currency: currency)
        return BatteryRefillViewState.PaymentMethod.OtherToken(
            chain: .init(id: chain.rawValue, title: chain.addressConfiguration.title, image: chain.addressConfiguration.icon),
            row: AssetBalanceRowCellContent(
                id: method.id,
                title: symbol,
                badge: badge,
                displayMode: .includingDiffs(
                    balance: isSecureMode ? .secureModeValueShort : balance,
                    price: unitPrice.map { amountFormatter.format(decimal: $0, accessory: .fiat(currency), style: .compact) } ?? "",
                    delta: nil,
                    fiat: isSecureMode ? .secureModeValueShort : fiat.map { amountFormatter.format(decimal: $0, accessory: .fiat(currency), style: .compact) } ?? "",
                    showsPin: false,
                    priceColor: .textSecondary
                ),
                avatarImageSource: imageSource
            )
        )
    }

    func jettonBalance(_ jettonItem: JettonItem) -> JettonBalance? {
        balanceStore.getState()[wallet]?.walletBalance.balance.jettonsBalance.first { $0.item == jettonItem }
    }

    func paymentMethod(_ method: Method) -> BatteryRefillViewState.PaymentMethod {
        paymentMethod(method, isSelected: method.id == selectedMethod?.id)
    }

    func paymentMethod(_ method: Method, isSelected: Bool) -> BatteryRefillViewState.PaymentMethod {
        switch method {
        case let .asset(asset):
            let amount = appSettingsStore.getState().isSecureMode ? String.secureModeValueShort : amountFormatter.format(amount: asset.asset.balance, fractionDigits: asset.method.decimals, accessory: .tokenSymbol(asset.method.symbol), style: .compact)
            return BatteryRefillViewState.PaymentMethod(
                id: method.id,
                icon: .asset(AssetIdResolver.imageSource(for: asset.method.assetId, imageUrl: asset.method.imageURL, multichainEnabled: true)),
                name: asset.method.symbol,
                caption: [asset.method.chain?.displayTitle, TKLocales.Battery.Refill.balance(amount)].compactMap { $0 }.joined(separator: " · "),
                isSelected: isSelected
            )
        case .appStore:
            return BatteryRefillViewState.PaymentMethod(
                id: method.id,
                icon: .appStore,
                name: TKLocales.Battery.Refill.AppStore.title,
                caption: TKLocales.Battery.Refill.AppStore.caption,
                isSelected: isSelected
            )
        case let .token(token):
            let network = tonNetwork
            let icon: BatteryRefillViewState.PaymentMethod.Icon = switch token {
            case .ton: .ton
            case let .jetton(jettonItem): .asset(.url(jettonItem.jettonInfo.imageURL, chainIcon: network?.tokenIcon20))
            }
            let balance = appSettingsStore.getState().isSecureMode
                ? String.secureModeValueShort
                : amountFormatter.format(
                    amount: balance(token: token),
                    fractionDigits: token.fractionDigits,
                    accessory: .tokenSymbol(token.symbol),
                    style: .compact
                )
            return BatteryRefillViewState.PaymentMethod(
                id: method.id,
                icon: icon,
                name: token.symbol,
                caption: [network?.displayTitle, TKLocales.Battery.Refill.balance(balance)].compactMap { $0 }.joined(separator: " · "),
                isSelected: isSelected
            )
        }
    }

    /// A multichain wallet names the network of every token, TON's too. TON itself gets no badge, like other networks' own coins.
    var tonNetwork: MultichainChain? {
        wallet.isMultichain ? .ton : nil
    }

    func balance(token: TonToken) -> BigUInt {
        let balance = balanceStore.getState()[wallet]?.walletBalance.balance
        switch token {
        case .ton:
            return BigUInt(balance?.tonBalance.amount ?? 0)
        case let .jetton(jettonItem):
            return balance?.jettonsBalance.first(where: { $0.item == jettonItem })?.quantity ?? 0
        }
    }

    /// Points the crypto packs at the selected token, then redraws.
    func updatePaymentMethod() {
        if case let .token(token) = selectedMethod {
            if let rechargeModel {
                if rechargeModel.token != token {
                    rechargeModel.token = token
                }
            } else {
                let rechargeModel = makeRechargeModel(token)
                rechargeModel.didUpdateOptionItems = { [weak self] in self?.updateState() }
                rechargeModel.didUpdateBalance = { [weak self] in self?.updateAmountInput() }
                rechargeModel.didUpdateRate = { [weak self] in self?.updateAmountInput() }
                rechargeModel.didUpdateIsContinueEnable = { [weak self] in self?.updateState() }
                self.rechargeModel = rechargeModel
                rechargeModel.start()
            }
        }
        updateAmountInput()
    }

    /// Points the amount field at the selected method; a new method clears the amount.
    func updateAmountInput() {
        guard let method = selectedMethod else { return updateState() }
        let isNewMethod = amountInputMethodId != method.id
        switch method {
        case let .asset(asset):
            if isNewMethod { amountInputViewModel.sourceUnit = asset.asset }
            amountInputViewModel.sourceBalance = asset.asset.balance
            amountInputViewModel.rate = NSDecimalNumber(decimal: asset.rate ?? 0)
            amountInputViewModel.minimumSourceAmount = asset.minimum
            amountInputViewModel.minimumDisplayStyle = .exactValue
        case let .token(token):
            guard let rechargeModel else { return updateState() }
            if isNewMethod { amountInputViewModel.sourceUnit = token }
            amountInputViewModel.sourceBalance = rechargeModel.balance
            amountInputViewModel.rate = rechargeModel.tonChargeRate
            amountInputViewModel.minimumSourceAmount = rechargeModel.minimumAmount
            amountInputViewModel.minimumDisplayStyle = .compact
        case .appStore:
            break
        }
        amountInputMethodId = method.id
        updateState()
    }
}

// MARK: - State updates

private extension BatteryRefillViewModelImplementation {
    func updateState() {
        let method = showsRefill ? selectedMethod : nil
        let packs = method.map { packs(method: $0) } ?? []
        state = BatteryRefillViewState(
            header: header,
            showsTronBanner: showsRefill && wallet.supportedBatteryTransactions.contains(.trc20),
            packs: packs,
            showsAmount: packs.contains { $0.id == Self.customPackId && $0.isSelected },
            paymentMethod: method.map { paymentMethod($0) },
            paymentCaption: method == nil ? nil : paymentCaption(),
            links: showsRefill && rechargeMethodItems.contains(where: { if case .gift = $0 { true } else { false } })
                ? [.gift, .history]
                : [.history],
            showsPromocode: showsRefill && !configuration.isDisableBatteryPromoModule(network: wallet.network),
            footer: showsRefill
                ? TKLocales.Battery.Refill.Footer.description
                : TKLocales.Battery.Refill.Footer.unavailable,
            mainButton: method.flatMap { mainButton(method: $0, packs: packs) },
            showsCloseButton: showsCloseButton
        )
        // A field shown again, after another method or pack, waits for a tap.
        if !state.showsAmount, amountInputViewModel.focusRequest > 0 {
            amountInputViewModel.resetFocusRequest()
        }
    }

    func packs(method: Method) -> [BatteryRefillViewState.Pack] {
        switch method {
        case let .asset(asset):
            let rows = asset.packages.sorted { $0.charges > $1.charges }
            let selectedId = selectedPackId(methodId: method.id, enabledIds: rows.filter { pack in asset.amount(for: pack).map(asset.canBuy) ?? false }.map(\.id), allowsCustom: true)
            return rows.compactMap { pack in
                guard let amount = asset.amount(for: pack) else { return nil }
                let belowMinimum = amount < (asset.minimum ?? 0)
                let currency = currencyStore.getState()
                let fiat = asset.fiatAmount(amount, currency: currency).map { "≈ " + amountFormatter.format(decimal: $0, accessory: .fiat(currency), style: .compact) }
                let caption = belowMinimum ? TKLocales.MultichainSwap.Screen.Swap.minimumAmount(assetAmount(asset.minimum ?? 0, asset: asset)) : [chargesCaption(chargesCount: pack.charges), fiat].compactMap { $0 }.joined(separator: " · ")
                return BatteryRefillViewState.Pack(id: pack.id, title: assetAmount(amount, asset: asset), caption: caption, icon: .fill(CGFloat(pack.charges) / CGFloat(max(rows.first?.charges ?? 1, 1))), isEnabled: asset.canBuy(amount), isSelected: selectedId == pack.id)
            } + [.init(id: Self.customPackId, title: TKLocales.Battery.Recharge.СustomInput.title, caption: TKLocales.Battery.Recharge.СustomInput.caption, icon: .other, isEnabled: asset.isReady, isSelected: selectedId == Self.customPackId)]
        case .appStore:
            let rows = inAppPurchaseItems.map { item -> (id: String, title: String, charges: Int?, percent: CGFloat, isEnabled: Bool) in
                switch item.state {
                case .loading:
                    (item.pack.productIdentifier, TKLocales.Toast.loading, nil, item.pack.batteryPercent, false)
                case let .amount(amount):
                    (
                        item.pack.productIdentifier,
                        amountFormatter.format(decimal: amount.price, accessory: .fiat(amount.currency), style: .compact),
                        amount.charges,
                        item.pack.batteryPercent,
                        item.isEnable
                    )
                }
            }
            let selectedId = selectedPackId(methodId: method.id, enabledIds: rows.filter(\.isEnabled).map(\.id))
            let bestValueId = rows.max { ($0.charges ?? 0) < ($1.charges ?? 0) }?.id
            return rows.map { row in
                BatteryRefillViewState.Pack(
                    id: row.id,
                    title: row.title,
                    caption: row.charges.map { chargesCaption(chargesCount: $0) } ?? "",
                    icon: .fill(row.percent),
                    tag: row.charges != nil && row.id == bestValueId && rows.count > 1 ? TKLocales.Battery.Refill.bestValue : nil,
                    isEnabled: row.isEnabled,
                    isSelected: row.id == selectedId
                )
            }
        case .token:
            guard let rechargeModel else { return [] }
            let selectedId = selectedPackId(
                methodId: method.id,
                enabledIds: rechargeModel.prefilledOptions.filter(\.isEnable).map(\.identifier),
                allowsCustom: true
            )
            return rechargeModel.packs(selectedId: selectedId, amountFormatter: amountFormatter)
        }
    }

    func paymentCaption() -> String? {
        guard let charges = batteryCalculation.calculateSwapsMinimumChargesAmount(network: wallet.network) else {
            return nil
        }
        return TKLocales.Battery.Refill.payWithCaption(chargesCaption(chargesCount: charges))
    }

    func assetAmount(_ amount: BigUInt, asset: BatteryRechargeAsset) -> String {
        amountFormatter.format(amount: amount, fractionDigits: asset.method.decimals, accessory: .tokenSymbol(asset.method.symbol), style: .exactValue)
    }

    func selectedPackId(methodId: String, enabledIds: [String], allowsCustom: Bool = false) -> String? {
        let packId = Self.packId(previous: selectedPackIds[methodId], enabledIds: enabledIds, allowsCustom: allowsCustom)
        selectedPackIds[methodId] = packId
        return packId
    }

    func mainButton(method: Method, packs: [BatteryRefillViewState.Pack]) -> BatteryRefillViewState.MainButton? {
        guard !packs.isEmpty else { return nil }
        guard let pack = packs.first(where: \.isSelected) else {
            return BatteryRefillViewState.MainButton(title: TKLocales.MultichainSwap.Screen.Confirm.topUpBattery, isEnabled: false)
        }
        if pack.id == Self.customPackId {
            return BatteryRefillViewState.MainButton(
                title: customAmountTitle(method: method).map { TKLocales.Battery.Refill.topUpFor($0) }
                    ?? TKLocales.MultichainSwap.Screen.Confirm.topUpBattery,
                isEnabled: isCustomAmountValid(method: method)
            )
        }
        if case .appStore = method {
            return BatteryRefillViewState.MainButton(
                title: TKLocales.Battery.Refill.payWith(TKLocales.Battery.Refill.AppStore.title),
                isEnabled: pack.isEnabled
            )
        }
        return BatteryRefillViewState.MainButton(
            title: TKLocales.Battery.Refill.topUpFor(pack.title),
            isEnabled: pack.isEnabled
        )
    }

    func isCustomAmountValid(method: Method) -> Bool {
        switch method {
        case let .asset(asset): asset.canBuy(customAmount)
        case .appStore: false
        case .token: customAmount > 0 && rechargeModel?.amount == customAmount && rechargeModel?.isContinueEnable == true
        }
    }

    func customChargesCaption(_ charges: BigUInt?) -> String? {
        guard customAmount > 0, let charges else { return nil }
        return "≈ " + chargesCaption(chargesCount: Int(clamping: charges))
    }

    func customAmountTitle(method: Method) -> String? {
        guard customAmount > 0 else { return nil }
        switch method {
        case let .asset(asset):
            return assetAmount(customAmount, asset: asset)
        case .appStore:
            return nil
        case let .token(token):
            return amountFormatter.format(amount: customAmount, fractionDigits: token.fractionDigits, accessory: .tokenSymbol(token.symbol), style: .exactValue)
        }
    }

    func loadNetworks() {
        Task { @MainActor [weak self, relayedEVMChains, wallet] in
            let networks = BatteryNetworks(relayedEVMChains: await relayedEVMChains() ?? [], wallet: wallet)
            guard let self else { return }
            self.networks = networks
            updateHeader(state: headerModel.getState())
        }
    }

    func updateHeader(state: BatteryRefillHeaderModel.State) {
        let description = networks.includesSolana && networks.includesEVM
            ? TKLocales.Battery.Refill.solanaCaption
            : networks.includesEVM ? TKLocales.Battery.Refill.evmCaption : TKLocales.Battery.Refill.emptyCaption
        switch state.charge {
        case let .charged(chargesCount, batteryPercent):
            header = BatteryRefillViewState.Header(
                batteryState: .fill(batteryPercent),
                charges: chargesCaption(chargesCount: chargesCount),
                description: description,
                warning: nil
            )
        case let .refunded(chargesCount):
            header = BatteryRefillViewState.Header(
                batteryState: .negative,
                charges: chargesCaption(chargesCount: chargesCount),
                description: description,
                warning: TKLocales.Battery.Refill.negativeBalanceCaption
            )
        case .notCharged:
            header = BatteryRefillViewState.Header(
                batteryState: .emptyTinted,
                charges: nil,
                description: description,
                warning: nil
            )
        }
        updateState()
    }

    func chargesCaption(chargesCount: Int) -> String {
        let count = amountFormatter.format(decimal: Decimal(chargesCount), style: .compact)
        return "\(count) \(TKLocales.Battery.Refill.chargesCount(count: abs(chargesCount)))"
    }

    func updateRechargeMethods(state: BatteryRefillRechargeMethodsModel.State) {
        switch state {
        case let .loading(items):
            rechargeMethodItems = items
        case let .idle(items):
            rechargeMethodItems = items
        }
        updatePaymentMethod()
    }

    func createRefundURL() -> URL? {
        guard let tonProof = try? tonProofTokenService.getWalletToken(wallet),
              let batteryRefundEndpoint = configuration.batteryRefundEndpoint(network: wallet.network)
        else {
            return nil
        }
        var components = URLComponents(url: batteryRefundEndpoint, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "token", value: tonProof),
            URLQueryItem(name: "testnet", value: String(wallet.network == .testnet)),
        ]
        return components?.url
    }

    func setupPromocode() {
        promocodeOutput.didUpdateResolvingState = { [weak self] state in
            switch state {
            case .failed, .none, .resolving:
                self?.promocode = nil
            case let .success(promocode):
                self?.promocode = promocode
            }
        }
    }
}
