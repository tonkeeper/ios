import AppUI
import BigInt
import Combine
import Foundation
import KeeperCore
import TKAppInfo
import TKCore
import TKLocalize
import TKUIKit
import UIKit

@MainActor
final class MoonPayRampViewModel: ObservableObject {
    var onClose: (() -> Void)?
    var onSelectCurrency: (([RemoteCurrency], RemoteCurrency) -> Void)?
    var onCryptoDeposit: (() -> Void)?
    var onSelectAsset: ((String) -> Void)?
    var onFailure: ((String) -> Void)?
    var onOffline: (() -> Void)?
    var onPriceDetails: (() -> Void)?

    let amountViewModel: AmountInputSwiftUIViewModel

    private(set) var asset: MultichainAsset?
    @Published private(set) var fiatAmount: BigUInt = 0
    @Published private var currentCurrency: RemoteCurrency
    @Published private var rateShowsAssetFirst = false
    @Published private var rateRestartToken = 0
    @Published private var rateTimerDuration = MoonPayRampViewModel.defaultRateTimerDuration
    @Published private var quoteRate: Decimal?
    /// A quote's rate was applied, shown or not; its timer must keep refreshing it.
    @Published private var hasQuoteRate = false
    @Published private var isConnecting = false
    /// MoonPay asked for a sign-in when the screen opened: the merchants fill the screen until
    /// Continue presents it.
    @Published private var isMoonPaySignInPending = false
    /// The customer has a MoonPay connection: checked when the screen opened, or signed in since.
    @Published private var isMoonPayConnected = false
    @Published private var isSigningIn = false
    /// Bumped to put the cursor in the amount field, such as after "Change amount".
    @Published private(set) var amountFocusRequest = 0
    @Published private var isLoadingDefaultAsset = false
    @Published private var hasNoAssetsForCurrency = false

    private let currenciesService: CurrenciesService
    private let currencyStore: CurrencyStore
    private let merchant: MerchantRampSource
    private let moonPay: MoonPayRampSource
    private let loadDefaultAsset: (String) async throws -> MultichainAsset?
    private let isNetworkUnavailable: () -> Bool
    /// "No internet connection" describes a lasting state: a failure nobody asked for, such as a
    /// quote refresh, does not repeat it more often than this; an action the user took, an amount
    /// or a method pick included, always shows it.
    /// System uptime, which the wall clock's corrections do not move.
    private var lastOfflineToast: TimeInterval?
    private static let offlineToastInterval: TimeInterval = 30
    private var active: any RampDataSource
    private var currencies: [RemoteCurrency] = []
    private var loadTask: Task<Void, Never>?
    private var connectTask: Task<Void, Never>?
    private var signInTask: Task<Void, Never>?
    private var defaultAssetTask: Task<Void, Never>?
    private var currenciesRetryTask: Task<Void, Never>?
    /// The list is being loaded at the start.
    private var isLoadingCurrencies = false
    /// Asset and currency pairs our backend did not sell, for which MoonPay was given another try.
    private var moonPayRetriedForUnsold: Set<String> = []
    private var suggestedAmount: BigUInt?
    private var minimumAmount: Decimal?
    @Published private var isMinimumLoading = false
    private var cancellables = Set<AnyCancellable>()

    init(
        asset: MultichainAsset?,
        currenciesService: CurrenciesService,
        currencyStore: CurrencyStore,
        merchant: MerchantRampSource,
        moonPay: MoonPayRampSource,
        loadDefaultAsset: @escaping (String) async throws -> MultichainAsset?,
        amountViewModel: AmountInputSwiftUIViewModel,
        isNetworkUnavailable: @escaping () -> Bool = { false }
    ) {
        self.isNetworkUnavailable = isNetworkUnavailable
        self.asset = asset
        self.currenciesService = currenciesService
        self.currencyStore = currencyStore
        self.merchant = merchant
        self.moonPay = moonPay
        self.loadDefaultAsset = loadDefaultAsset
        self.amountViewModel = amountViewModel
        active = merchant
        currentCurrency = .default
        merchant.host = self
        moonPay.host = self
        amountViewModel.objectWillChange
            .merge(with: merchant.objectWillChange)
            .merge(with: moonPay.objectWillChange)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    deinit {
        loadTask?.cancel()
        connectTask?.cancel()
        signInTask?.cancel()
        defaultAssetTask?.cancel()
    }

    /// Who Continue goes to. A merchant the user picked stands; otherwise MoonPay where it is
    /// offered, else the merchant with the best rate.
    var provider: RampProvider {
        if isMoonPayActive { return .moonPay }
        if let preferred = merchant.preferredMerchant { return .merchant(id: preferred.id) }
        if isMoonPaySignInPending, moonPayWidgetSellsCurrentPurchase { return .moonPay }
        return .merchant(id: nil)
    }

    /// MoonPay can be picked in the provider sheet.
    var isMoonPayOffered: Bool {
        if isMoonPayConnected { return moonPayTakesCurrentPurchase }
        return isMoonPaySignInPending && moonPayWidgetSellsCurrentPurchase
    }

    var listsMoonPayWidgetMethods: Bool {
        provider == .moonPay && !isMoonPayActive
    }

    /// What the payment method screen shows after "via".
    var providerName: String? {
        switch provider {
        case .moonPay: Self.moonPayName
        case .merchant: merchant.currentMerchantTitle
        }
    }

    /// The merchant the screen buys through now: the picked one or the one with the best rate.
    var merchantId: String? {
        guard case let .merchant(id) = provider else { return nil }
        return id ?? merchant.currentMerchantId
    }

    static let moonPayName = BuyCryptoAnalytics.moonPayProvider

    /// What Continue would buy now, as the deposit funnel names it: nil until the asset, the
    /// method and the provider are known, and for P2P, which has no provider. A merchant counts
    /// as known once a quote named it or the user picked it; its slug stands in for a title the
    /// merchants list has not brought yet.
    var analyticsPurchase: BuyCryptoPurchase? {
        guard let asset, let method = active.analyticsMethod else { return nil }
        let providerName: String
        let mode: RampProviderMode
        // As Continue decides: before the sign-in MoonPay is the provider, but a method its widget
        // does not take skips the sign-in for the merchant with the best rate.
        if isMoonPayActive || opensMoonPaySignIn {
            providerName = Self.moonPayName
            mode = .headless
        } else {
            guard merchant.isMerchantKnown,
                  let name = merchant.currentMerchantTitle ?? merchant.currentMerchantId
            else { return nil }
            providerName = name
            mode = .merchant
        }
        return BuyCryptoPurchase(
            assetId: asset.asset.assetId,
            fiat: currentCurrency.code,
            paymentMethod: method,
            provider: providerName,
            mode: mode
        )
    }

    /// The purchase the amount screen shows, once its methods have loaded; a failed quote does
    /// not hold it back.
    var shownPurchase: BuyCryptoPurchase? {
        guard !isLoadingState, placeholder == nil else { return nil }
        return analyticsPurchase
    }

    private var moonPayTakesCurrentPurchase: Bool {
        moonPay.mayTake(currency: currentCurrency.code) && asset.map { moonPay.maySell(assetId: $0.asset.assetId) } ?? true
    }

    /// Before the sign-in only our backend tells whether MoonPay sells the asset in the currency:
    /// it lists MoonPay's widget there. Until the methods load it does not, so the screen opens on
    /// the merchants rather than ask for a sign-in that may buy nothing.
    private var moonPayWidgetSellsCurrentPurchase: Bool {
        moonPayTakesCurrentPurchase && merchant.listsMoonPayWidget
    }

    /// The payment methods reload for MoonPay. Before the sign-in the merchants stay on screen,
    /// and Continue presents it.
    func selectMoonPay() {
        merchant.selectMerchant(nil)
        if isMoonPayActive {
            active.reloadMethods()
        } else if isMoonPayConnected {
            useMoonPaySource()
        } else {
            merchant.reloadMethods()
        }
        objectWillChange.send()
    }

    /// Continue goes to this merchant, whatever another one's rate.
    func selectMerchant(id: String, title: String) {
        merchant.selectMerchant((id: id, title: title))
        if isMoonPayActive {
            useMerchantSource()
        } else {
            merchant.reloadMethods()
        }
        objectWillChange.send()
    }

    /// The merchants fill the screen, but Continue presents MoonPay's sign-in for a method MoonPay
    /// takes; any other, P2P included, goes to its merchant.
    private var opensMoonPaySignIn: Bool {
        provider == .moonPay && !isMoonPayActive && !merchant.isP2PSelected && merchant.selectedMethodTakesMoonPayWidget
    }

    private var isActionEnabled: Bool {
        guard !isLoadingState, placeholder == nil else { return false }
        guard opensMoonPaySignIn else { return active.isActionEnabled }
        // MoonPay's quote and limits come only after the sign-in; the merchants' do not apply.
        return asset != nil && fiatAmount > 0 && !isSigningIn
    }

    /// The payment methods of the source on screen are not loaded yet.
    var isLoadingPaymentMethods: Bool {
        isLoadingState
    }

    private var isLoadingState: Bool {
        isConnecting || isLoadingDefaultAsset || active.isLoadingMethods
    }

    private var placeholder: MoonPayRampViewState.Placeholder? {
        guard !isLoadingState else { return nil }
        let hasNothingToBuy = asset == nil ? hasNoAssetsForCurrency : active.hasNoPaymentMethods
        guard hasNothingToBuy else { return nil }
        let name = currentCurrency.name.isEmpty || currentCurrency.name == currentCurrency.code
            ? currentCurrency.code
            : "\(currentCurrency.name) (\(currentCurrency.code))"
        return .init(
            title: TKLocales.Ramp.Moonpay.NoMethods.title,
            subtitle: TKLocales.Ramp.Moonpay.NoMethods.subtitle(name),
            changeCurrencyTitle: TKLocales.Ramp.Moonpay.NoMethods.changeCurrency,
            cryptoDepositTitle: TKLocales.Ramp.Moonpay.cryptoDeposit
        )
    }

    var screenState: MoonPayRampViewState {
        var amount = amountViewModel.sheetState()
        // Out of the limits, the amount turns red and Continue names the limit. The merchants'
        // limits do not apply while Continue opens MoonPay's sign-in.
        let limitTitle = opensMoonPaySignIn ? nil : active.actionTitle
        amount.isTextError = limitTitle != nil
        amount.converted?.highlightsAmount = true
        // A quick option only fills in its amount: it is never shown as picked.
        amount.quickOptions = amount.quickOptions.map { option in
            var option = option
            option.isSelected = false
            return option
        }
        if isLoadingState {
            amount.converted?.isLoading = true
        }
        amount.isQuickOptionsLoading = isLoadingState || isMinimumLoading
        return MoonPayRampViewState(
            title: TKLocales.Ramp.Moonpay.title,
            payInCaption: TKLocales.Ramp.Moonpay.payIn,
            currencyCode: currentCurrency.code,
            currencyImageURL: URL(string: currentCurrency.image),
            amount: amount,
            rateText: rateText,
            rateRestartToken: rateRestartToken,
            rateTimerDuration: rateTimerDuration,
            keepsRateTimer: hasQuoteRate,
            priceDetailsTitle: priceDetailsState == nil ? nil : TKLocales.Ramp.Moonpay.PriceDetails.inclFees,
            payment: active.payment,
            actionTitle: limitTitle ?? TKLocales.Actions.continueAction,
            isActionEnabled: isActionEnabled,
            isPayable: inlineAction.map(\.isEnabled) ?? isActionEnabled,
            isActionLoading: isSigningIn || active.isActionLoading,
            isLoading: isLoadingState,
            placeholder: placeholder,
            disclosures: isLoadingState ? [] : MoonPayPaymentDisclosures.texts(for: active.paymentDisclosures)
        )
    }

    var inlineAction: RampInlineAction? {
        guard let action = active.inlineAction else { return nil }
        return RampInlineAction(
            controller: action.controller,
            isReady: action.isReady,
            isEnabled: action.isEnabled && !isLoadingState && placeholder == nil
        )
    }

    func start() {
        amountViewModel.isBalanceVisible = false
        amountViewModel.isMaxButtonVisible = false
        amountViewModel.isCurrencySwitchEnabled = false
        amountViewModel.isConvertedSelectable = true
        amountViewModel.didTapConverted = { [weak self] in
            self?.selectAsset()
        }
        amountViewModel.didUpdateSourceAmount = { [weak self] amount in
            // The field writes its text back as it loses focus: the same amount is no new quote.
            guard let self, amount != fiatAmount else { return }
            fiatAmount = amount
            guard !isConnecting else { return }
            active.amountDidChange()
        }
        applyAssetIcon()
        applyCurrency(currentCurrency)
        isLoadingDefaultAsset = asset == nil
        isLoadingCurrencies = true
        loadTask = Task { [weak self] in
            await self?.loadCurrencies()
            self?.isLoadingCurrencies = false
            guard !Task.isCancelled else { return }
            self?.loadDefaultAssetIfNeeded()
        }
        chooseInitialSource()
    }

    func close() {
        onClose?()
    }

    func focusAmount() {
        amountFocusRequest += 1
    }

    /// The screen is gone: a connect or sign-in still running must not present MoonPay's sign-in,
    /// show an error or reload a source over it.
    func tearDown() {
        connectTask?.cancel()
        signInTask?.cancel()
        loadTask?.cancel()
        defaultAssetTask?.cancel()
        currenciesRetryTask?.cancel()
        isSigningIn = false
    }

    /// The list failed to load at the start: loads it again and opens the picker once it is there,
    /// since the stub's Change currency has no other way to work. The retry only fills the list:
    /// the currency on screen stays until the user picks one.
    func tapCurrency() {
        guard currencies.isEmpty else {
            onSelectCurrency?(currencies, currentCurrency)
            return
        }
        // The first load is still running and fills the list.
        guard !isLoadingCurrencies, currenciesRetryTask == nil else { return }
        currenciesRetryTask = Task { [weak self] in
            let fiat: [RemoteCurrency]
            var failure: Error?
            do {
                fiat = try await self?.fetchFiatCurrencies() ?? []
            } catch {
                fiat = []
                failure = error
            }
            guard let self, !Task.isCancelled else { return }
            currenciesRetryTask = nil
            if !fiat.isEmpty {
                currencies = fiat
                onSelectCurrency?(fiat, currentCurrency)
            } else if let failure {
                reportFailure(failure)
            } else {
                onFailure?(TKLocales.Errors.unknown)
            }
        }
    }

    /// Another route opens: a currency retry still running must not present its picker over it.
    private func cancelCurrenciesRetry() {
        currenciesRetryTask?.cancel()
        currenciesRetryTask = nil
    }

    /// The same receive screen as Payment method → Crypto deposit: the only way there while
    /// the currency has no payment methods.
    func tapCryptoDeposit() {
        cancelCurrenciesRetry()
        onCryptoDeposit?()
    }

    func setCurrency(_ currency: RemoteCurrency) {
        guard currency.code != currentCurrency.code else { return }
        currentCurrency = currency
        applyCurrency(currency)
        reloadPreferringMoonPay()
        loadDefaultAssetIfNeeded()
    }

    func setAsset(_ newAsset: MultichainAsset) {
        guard asset?.asset.assetId != newAsset.asset.assetId else { return }
        asset = newAsset
        defaultAssetTask?.cancel()
        isLoadingDefaultAsset = false
        hasNoAssetsForCurrency = false
        amountViewModel.replaceDestinationUnit(MoonPayRampAssetUnit(asset: newAsset))
        applyAssetIcon()
        reloadPreferringMoonPay()
    }

    func toggleRateDirection() {
        rateShowsAssetFirst.toggle()
    }

    func tapPriceDetails() {
        onPriceDetails?()
    }

    /// What the quote on screen is made of; nil until MoonPay quotes the amount typed.
    var priceDetailsState: MoonPayPriceDetailsViewState? {
        typealias Details = TKLocales.Ramp.Moonpay.PriceDetails
        guard !isLoadingState, !rateText.isEmpty, let quote = active.priceQuote else { return nil }
        let posix = Locale(identifier: "en_US_POSIX")
        let paid = quote.source.amount.flatMap { Decimal(string: $0, locale: posix) }
        let received = quote.destination.amount.flatMap { Decimal(string: $0, locale: posix) }
        guard let paid, let received else { return nil }
        return MoonPayPriceDetailsViewState(
            youPay: .init(
                id: "pay",
                title: Details.youPay,
                value: MoonPayPaymentStatusViewModel.paidText(paid, code: quote.source.asset.code, dropsWholeCents: true)
            ),
            rateTitle: Details.rate,
            rateText: rateText,
            rateRestartToken: rateRestartToken,
            rateTimerDuration: rateTimerDuration,
            fees: MoonPayQuoteFees.rows(of: quote).map { .init(id: $0.id, title: $0.title, value: $0.value) },
            youGet: .init(id: "get", title: Details.youGet, value: "\(Self.formatDisplayAmount(received)) \(assetLabel)")
        )
    }

    func completeRateTimer() {
        guard active.canRefreshQuote else {
            rateRestartToken += 1
            return
        }
        active.refreshQuote()
    }

    func tapPaymentMethod() {
        cancelCurrenciesRetry()
        active.tapPaymentMethod()
    }

    func setPaymentMethod(_ type: String) {
        active.selectMethod(type)
    }

    func tapAction() {
        cancelCurrenciesRetry()
        guard opensMoonPaySignIn else {
            active.tapAction()
            return
        }
        signInToMoonPay()
    }

    /// After the sign-in the screen stays, now with MoonPay's methods and quote; the payment starts
    /// only on the next Continue, once the user has seen what MoonPay gives.
    private func signInToMoonPay() {
        guard !isSigningIn else { return }
        isSigningIn = true
        let moonPay = moonPay
        signInTask = Task { [weak self] in
            do {
                try await moonPay.signIn()
                guard let self, !Task.isCancelled else { return }
                isSigningIn = false
                isMoonPaySignInPending = false
                isMoonPayConnected = true
                useMoonPaySource()
            } catch {
                guard let self, !Task.isCancelled else { return }
                isSigningIn = false
                switch error {
                case MoonPayRampError.verificationCancelled:
                    break
                case MoonPayRampError.verificationFailed(.failed), MoonPayRampError.verificationFailed(.unavailable):
                    // MoonPay refused this customer, or its credentials do not decrypt, which a retry
                    // does not change: Continue goes to the merchants now. A sign-in that ended at
                    // another status may pass on another try.
                    isMoonPaySignInPending = false
                    // The list kept MoonPay's widget's methods while the sign-in waited.
                    reloadActive()
                    reportFailure(error)
                default:
                    reportFailure(error)
                }
            }
        }
    }

    func reload() {
        reloadActive()
    }

    func refresh() {
        objectWillChange.send()
    }

    // MARK: - Source

    /// MoonPay is tried first, without its sign-in: the screen waits in a loading state for the
    /// connection, and shows the merchants unless the customer is connected already.
    private func chooseInitialSource() {
        isConnecting = true
        let moonPay = moonPay
        connectTask = Task { [weak self] in
            let check = await moonPay.checkConnection()
            guard let self, !Task.isCancelled else { return }
            isConnecting = false
            switch check {
            case .connected:
                isMoonPayConnected = true
                useMoonPaySource()
            case .signInRequired:
                isMoonPaySignInPending = true
                merchant.reloadMethods()
            case .unavailable:
                merchant.reloadMethods()
            }
        }
    }

    private func reloadActive() {
        guard !isConnecting else { return }
        active.reloadMethods()
    }

    /// A new asset or currency gives a connected MoonPay another try: the merchants may have taken
    /// over only because MoonPay could not sell the previous one or take the previous currency. A
    /// currency MoonPay already had no method for goes straight to the merchants, whichever source
    /// is active: MoonPay's load would end in the same fallback, and the merchants keep their
    /// selection.
    private func reloadPreferringMoonPay() {
        // A currency MoonPay has no method for, or an asset it was found not to sell, goes to the
        // merchants; MoonPay comes back only for a purchase it may take.
        let takesPurchase = moonPayTakesCurrentPurchase
        if isMoonPayActive, !takesPurchase {
            useMerchantSource()
        } else if !isMoonPayActive, takesPurchase, moonPay.isConnected, merchant.preferredMerchant == nil {
            useMoonPaySource()
        } else {
            reloadActive()
        }
    }

    private var isMoonPayActive: Bool {
        moonPay === active
    }

    func useMoonPaySource() {
        guard !isMoonPayActive else { return }
        switchSource(to: moonPay, from: merchant)
    }

    func useMerchantSource() {
        guard isMoonPayActive else { return }
        switchSource(to: merchant, from: moonPay)
    }

    private func switchSource(to newSource: any RampDataSource, from oldSource: any RampDataSource) {
        oldSource.deactivate()
        active = newSource
        applyRate(nil)
        newSource.reloadMethods()
        objectWillChange.send()
    }

    // MARK: - Currency and asset

    /// The currencies the ramp offers: the fiat ones.
    private func fetchFiatCurrencies() async throws -> [RemoteCurrency] {
        try await currenciesService.loadCurrencies().filter { $0.currencyType == .fiat }
    }

    private func loadCurrencies() async {
        guard let fiat = try? await fetchFiatCurrencies(), !Task.isCancelled, !fiat.isEmpty else { return }
        currencies = fiat
        let selected = fiat.first { $0.code == currencyStore.state.code } ?? currentCurrency
        guard fiat.contains(where: { $0.code == selected.code }) else { return }
        let changed = selected.code != currentCurrency.code
        currentCurrency = selected
        applyCurrency(selected)
        if changed {
            reloadPreferringMoonPay()
        }
    }

    /// Owns `isLoadingDefaultAsset`: a task that was replaced, cancelled or outrun by a chosen asset
    /// leaves the flag to whoever took over.
    private func loadDefaultAssetIfNeeded() {
        defaultAssetTask?.cancel()
        guard asset == nil else {
            isLoadingDefaultAsset = false
            return
        }
        hasNoAssetsForCurrency = false
        isLoadingDefaultAsset = true
        let code = currentCurrency.code
        defaultAssetTask = Task { [weak self] in
            do {
                let defaultAsset = try await self?.loadDefaultAsset(code)
                guard let self, !Task.isCancelled, code == currentCurrency.code, asset == nil else { return }
                isLoadingDefaultAsset = false
                if let defaultAsset {
                    setAsset(defaultAsset)
                } else {
                    hasNoAssetsForCurrency = true
                }
            } catch {
                guard let self, !Task.isCancelled, code == currentCurrency.code, asset == nil else { return }
                isLoadingDefaultAsset = false
                reportFailure(error)
            }
        }
    }

    private func applyCurrency(_ currency: RemoteCurrency) {
        if (amountViewModel.sourceUnit as? RemoteCurrency)?.code != currency.code {
            amountViewModel.sourceUnit = currency
            minimumAmount = nil
            suggestedAmount = nil
        }
        applyQuickOptions(currency: currency)
    }

    private func applyQuickOptions(currency: RemoteCurrency) {
        amountViewModel.quickOptions = Self.quickAmounts(minimum: minimumAmount).map { amount in
            AmountInputQuickOption(
                id: String(amount),
                title: Self.quickOptionTitle(amount, currency: currency),
                amount: Decimal(amount)
            )
        }
    }

    private func selectAsset() {
        cancelCurrenciesRetry()
        onSelectAsset?(currentCurrency.code)
    }

    private func applyAssetIcon() {
        if let asset, let url = URL(string: asset.asset.image), !asset.asset.image.isEmpty {
            amountViewModel.convertedLeadingImage = nil
            amountViewModel.convertedLeadingImageURL = url
            amountViewModel.convertedLeadingChainImage = AssetIdResolver.chainIcon(
                for: asset.asset.assetId,
                multichainEnabled: true
            )
        } else {
            amountViewModel.convertedLeadingImageURL = nil
            amountViewModel.convertedLeadingChainImage = nil
            amountViewModel.convertedLeadingImage = .TKUIKit.Icons.Size20.cryptoUsdt
        }
    }

    // MARK: - Rate text

    private var rateText: String {
        guard let rate = quoteRate, rate > 0 else { return "" }
        if rateShowsAssetFirst {
            let inverse = Decimal(1) / rate
            return TKLocales.Ramp.Moonpay.rate(assetLabel, Self.formatFiat(inverse, currency: currentCurrency))
        }
        return TKLocales.Ramp.Moonpay.rate(currentCurrency.code, "\(Self.formatRate(rate)) \(assetLabel)")
    }

    private var assetLabel: String {
        Self.assetLabel(for: asset)
    }

    nonisolated static func assetLabel(for asset: MultichainAsset?) -> String {
        guard let asset else {
            return "USDT (TON)"
        }
        guard let chain = asset.asset.chain?.symbol,
              chain.caseInsensitiveCompare(asset.asset.symbol) != .orderedSame
        else {
            return asset.asset.symbol
        }
        return "\(asset.asset.symbol) (\(chain))"
    }

    /// Grouped as the limits are: "$1 000".
    static func quickOptionTitle(_ amount: Int, currency: RemoteCurrency) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "\u{00A0}"
        formatter.groupingSize = 3
        return withSymbol(formatter.string(from: NSNumber(value: amount)) ?? String(amount), currency: currency)
    }

    func formatLimit(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "\u{00A0}"
        formatter.groupingSize = 3
        let amount = formatter.string(from: value as NSDecimalNumber) ?? NSDecimalNumber(decimal: value).stringValue
        return Self.withSymbol(amount, currency: currentCurrency)
    }

    private static func formatFiat(_ value: Decimal, currency: RemoteCurrency) -> String {
        withSymbol(formatDisplayAmount(value), currency: currency)
    }

    private static func withSymbol(_ amount: String, currency: RemoteCurrency) -> String {
        let legacy = currency.legacyCurrency
        if legacy.symbolOnLeft {
            return "\(legacy.rampSymbol)\(amount)"
        }
        return "\(amount)\u{00A0}\(legacy.rampSymbol)"
    }

    /// As the design writes rates: up to 3 decimals and thousands split by a no-break space
    /// ("0.987", "1.002", "74 600"). A rate below 0.1, such as a dollar in BTC, keeps 4
    /// significant digits instead, which 3 decimals would round to nothing.
    static func formatRate(_ value: Decimal) -> String {
        format(value, maximumFractionDigits: 3, significantBelow: Decimal(string: "0.1")!, significantDigits: 4)
    }

    /// An amount to read rather than enter, such as a price in fiat or the amount a purchase
    /// brings, rounded as the app's other prices show them: up to 2 decimals from 1 up
    /// ("2 492.72"), 3 significant digits below ("0.123", "0.0492"), never abbreviated.
    static func formatDisplayAmount(_ value: Decimal) -> String {
        format(value, maximumFractionDigits: 2, significantBelow: 1, significantDigits: 3)
    }

    private static func format(
        _ value: Decimal,
        maximumFractionDigits: Int,
        significantBelow: Decimal,
        significantDigits: Int
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "\u{00A0}"
        formatter.groupingSize = 3
        if value < significantBelow {
            formatter.usesSignificantDigits = true
            formatter.minimumSignificantDigits = 1
            formatter.maximumSignificantDigits = significantDigits
        } else {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = maximumFractionDigits
        }
        return formatter.string(from: value as NSDecimalNumber) ?? NSDecimalNumber(decimal: value).stringValue
    }

    /// Not zero: `AmountInputSwiftUIViewModel` divides by the rate when the destination unit changes.
    private static let emptyRate = NSDecimalNumber(mantissa: 1, exponent: -30, isNegative: false)
    private static let defaultQuickAmounts = [50, 100, 500]

    private static let defaultRateTimerDuration: TimeInterval = 12
    /// The refresh starts this long before the quote expires, about the time its request takes, so
    /// the new quote lands as the old one runs out.
    private static let quoteRefreshLeadTime: TimeInterval = 1
    private static let rateTimerRange: ClosedRange<TimeInterval> = 3 ... 60

    static func rateTimerDuration(forQuoteLifetime lifetime: TimeInterval) -> TimeInterval {
        min(max(lifetime - quoteRefreshLeadTime, rateTimerRange.lowerBound), rateTimerRange.upperBound)
    }

    /// There is no exchange rate to the dollar here, but the minimum purchase is set in the selected
    /// currency, so the defaults (which suit a $20 minimum) are scaled by it.
    static func quickAmounts(minimum: Decimal?) -> [Int] {
        guard let minimum, minimum > 0 else { return defaultQuickAmounts }
        let value = NSDecimalNumber(decimal: minimum).doubleValue
        var result: [Int] = []
        for multiplier in [2.5, 5, 25] {
            var amount = niceAmount(value * multiplier)
            while let last = result.last, amount <= last {
                amount = nextNiceAmount(after: amount)
            }
            result.append(amount)
        }
        return result
    }

    private static func nextNiceAmount(after amount: Int) -> Int {
        let exponent = floor(log10(Double(amount)))
        let base = Double(amount) / pow(10, exponent)
        let next = [1.0, 2, 5, 10].first { $0 > base + 0.001 } ?? 10
        return Int((next * pow(10, exponent)).rounded())
    }

    /// The nearest of 1, 2, 5 and 10 times a power of ten, so amounts stay round.
    private static func niceAmount(_ value: Double) -> Int {
        let exponent = floor(log10(value))
        let base = value / pow(10, exponent)
        let step = [1.0, 2, 5, 10].min { abs(log($0 / base)) < abs(log($1 / base)) } ?? 1
        return max(1, Int((step * pow(10, exponent)).rounded()))
    }
}

extension MoonPayRampViewModel: RampDataSourceHost {
    private var canSuggestAmount: Bool {
        fiatAmount == 0 || fiatAmount == suggestedAmount
    }

    func setLoadingMinimum(_ isOn: Bool) {
        isMinimumLoading = isOn
    }

    func applyMinimumAmount(_ value: Decimal) {
        if minimumAmount != value {
            minimumAmount = value
            applyQuickOptions(currency: currentCurrency)
        }
        guard canSuggestAmount else { return }
        let units = RampDataSourceDefaults.minorUnits(value, fractionDigits: fractionDigits)
        guard units > 0, units != fiatAmount else { return }
        suggestedAmount = units
        amountViewModel.setInitialSourceAmount(amount: units)
    }

    var fiatCode: String {
        currentCurrency.code
    }

    var fractionDigits: Int {
        amountViewModel.sourceUnit.fractionalDigits
    }

    func applyRate(_ rate: Decimal?, displayRate: Decimal?) {
        guard let rate, rate > 0 else {
            quoteRate = nil
            hasQuoteRate = false
            amountViewModel.rate = Self.emptyRate
            return
        }
        hasQuoteRate = true
        // No rate line rather than one with fees mixed in.
        quoteRate = displayRate.flatMap { $0 > 0 ? $0 : nil }
        amountViewModel.rate = NSDecimalNumber(decimal: rate)
    }

    func setConvertedShimmering(_ isOn: Bool) {
        amountViewModel.isConvertedShimmering = isOn
    }

    func restartRateTimer(lifetime: TimeInterval?) {
        rateTimerDuration = lifetime.map(Self.rateTimerDuration(forQuoteLifetime:)) ?? Self.defaultRateTimerDuration
        rateRestartToken += 1
    }

    func reportFailure(_ error: Error) {
        report(error, throttlesOffline: false)
    }

    func reportQuoteFailure(_ error: Error) {
        report(error, throttlesOffline: true)
    }

    private func report(_ error: Error, throttlesOffline: Bool) {
        if case MultichainRampAPIError.cancelled = error { return }
        guard isOffline(error) else {
            onFailure?(TKLocales.Errors.unknown)
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        if throttlesOffline, let last = lastOfflineToast, now - last < Self.offlineToastInterval {
            return
        }
        lastOfflineToast = now
        onOffline?()
    }

    /// The device has no network, as the path monitor says, or the request failed for the lack
    /// of it: the error from our backend does not keep URLSession's code, MoonPay's does. With the
    /// monitor offline, MoonPay's own errors count too: its pages fail to load without a network.
    func isOffline(_ error: Error) -> Bool {
        isNetworkUnavailable() || RampConnectivity.isOfflineError(error)
    }

    func fallBackToMerchant() {
        useMerchantSource()
    }

    func merchantsDoNotSell() -> Bool {
        guard let asset else { return false }
        // Once: MoonPay failing to load again hands the screen back here, which then shows the stub.
        let key = "\(asset.asset.assetId)|\(currentCurrency.code)"
        guard !moonPayRetriedForUnsold.contains(key), merchantPickDidDrop() else { return false }
        moonPayRetriedForUnsold.insert(key)
        return true
    }

    /// MoonPay is the default again where it works.
    func merchantPickDidDrop() -> Bool {
        guard isMoonPayConnected, moonPayTakesCurrentPurchase, !isMoonPayActive else { return false }
        useMoonPaySource()
        return true
    }
}

struct MoonPayRampAssetUnit: AmountInputUnit {
    let inputSymbol: AmountInputSymbol
    let fractionalDigits: Int
    let symbol: String

    init(asset: MultichainAsset?) {
        let label = MoonPayRampViewModel.assetLabel(for: asset)
        inputSymbol = .text(label)
        fractionalDigits = asset?.asset.decimals ?? 6
        symbol = label
    }
}

extension Currency {
    /// The symbol a purchase names its currency with. The app writes these pesos as a bare "$",
    /// like dollars, so they take Android's symbols.
    var rampSymbol: String {
        switch code {
        case "ARS": "ARS$"
        case "COP": "COL$"
        default: symbol
        }
    }
}
