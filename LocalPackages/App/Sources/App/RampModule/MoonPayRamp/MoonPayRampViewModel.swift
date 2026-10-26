import AppUI
import BigInt
import Combine
import Foundation
import KeeperCore
import TKAppInfo
import TKLocalize
import TKUIKit
import UIKit

@MainActor
final class MoonPayRampViewModel: ObservableObject {
    var onClose: (() -> Void)?
    var onSelectCurrency: (([RemoteCurrency], RemoteCurrency) -> Void)?
    var onSelectAsset: ((String) -> Void)?
    var onFailure: ((String) -> Void)?

    let amountViewModel: AmountInputSwiftUIViewModel

    private(set) var asset: MultichainAsset?
    @Published private(set) var fiatAmount: BigUInt = 0
    @Published private var currentCurrency: RemoteCurrency
    @Published private var rateShowsAssetFirst = false
    @Published private var rateRestartToken = 0
    @Published private var quoteRate: Decimal?
    @Published private var isConnecting = false
    @Published private var isLoadingDefaultAsset = false
    @Published private var hasNoAssetsForCurrency = false

    private let currenciesService: CurrenciesService
    private let currencyStore: CurrencyStore
    private let merchant: MerchantRampSource
    private let moonPay: MoonPayRampSource?
    private let loadDefaultAsset: (String) async throws -> MultichainAsset?
    private var active: any RampDataSource
    private var currencies: [RemoteCurrency] = []
    private var loadTask: Task<Void, Never>?
    private var connectTask: Task<Void, Never>?
    private var defaultAssetTask: Task<Void, Never>?
    private var assetFallbackCurrencyCode: String?
    private var suggestedAmount: BigUInt?
    private var minimumAmount: Decimal?
    @Published private var isMinimumLoading = false
    private var cancellables = Set<AnyCancellable>()

    init(
        asset: MultichainAsset?,
        currenciesService: CurrenciesService,
        currencyStore: CurrencyStore,
        merchant: MerchantRampSource,
        moonPay: MoonPayRampSource?,
        loadDefaultAsset: @escaping (String) async throws -> MultichainAsset?,
        amountViewModel: AmountInputSwiftUIViewModel
    ) {
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
        moonPay?.host = self
        amountViewModel.objectWillChange
            .merge(with: merchant.objectWillChange)
            .merge(with: moonPay?.objectWillChange ?? ObservableObjectPublisher())
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    deinit {
        loadTask?.cancel()
        connectTask?.cancel()
        defaultAssetTask?.cancel()
    }

    private var isLoadingState: Bool {
        isConnecting || isLoadingDefaultAsset || active.isLoadingMethods
    }

    private var placeholder: MoonPayRampViewState.Placeholder? {
        guard !isLoadingState else { return nil }
        let hasNothingToBuy = asset == nil ? hasNoAssetsForCurrency : active.hasNoPaymentMethods
        guard hasNothingToBuy else { return nil }
        return .init(
            title: TKLocales.Ramp.PaymentMethod.noCashMethodsTitle,
            subtitle: TKLocales.Ramp.PaymentMethod.noCashMethodsSubtitle
        )
    }

    var screenState: MoonPayRampViewState {
        var amount = amountViewModel.sheetState()
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
            payment: active.payment,
            actionTitle: active.actionTitle ?? TKLocales.Actions.continueAction,
            limitText: active.limitText,
            isActionEnabled: !isLoadingState && placeholder == nil && active.isActionEnabled,
            isActionLoading: active.isActionLoading,
            isLoading: isLoadingState,
            placeholder: placeholder
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
            guard let self else { return }
            fiatAmount = amount
            guard !isConnecting else { return }
            active.amountDidChange()
        }
        applyAssetIcon()
        applyCurrency(currentCurrency)
        isLoadingDefaultAsset = asset == nil
        loadTask = Task { [weak self] in
            await self?.loadCurrencies()
            guard !Task.isCancelled else { return }
            self?.loadDefaultAssetIfNeeded()
        }
        chooseInitialSource()
    }

    func close() {
        onClose?()
    }

    func tapCurrency() {
        guard !currencies.isEmpty else { return }
        onSelectCurrency?(currencies, currentCurrency)
    }

    func setCurrency(_ currency: RemoteCurrency) {
        guard currency.code != currentCurrency.code else { return }
        currentCurrency = currency
        applyCurrency(currency)
        reloadActive()
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
        if let moonPay, !isMoonPayActive, moonPay.isConnected {
            useMoonPaySource()
        } else {
            reloadActive()
        }
    }

    func toggleRateDirection() {
        rateShowsAssetFirst.toggle()
    }

    func completeRateTimer() {
        guard active.canRefreshQuote else {
            rateRestartToken += 1
            return
        }
        active.refreshQuote()
    }

    func tapPaymentMethod() {
        active.tapPaymentMethod()
    }

    func setPaymentMethod(_ type: String) {
        active.selectMethod(type)
    }

    func tapAction() {
        active.tapAction()
    }

    func reload() {
        reloadActive()
    }

    func refresh() {
        objectWillChange.send()
    }

    // MARK: - Source

    /// MoonPay is tried first: the screen waits in a loading state for the connection, and falls
    /// back to the merchants only if it fails.
    private func chooseInitialSource() {
        guard let moonPay, moonPay.isConfigured else {
            merchant.reloadMethods()
            return
        }
        isConnecting = true
        connectTask = Task { [weak self] in
            let connected = await moonPay.connect()
            guard let self, !Task.isCancelled else { return }
            isConnecting = false
            if connected {
                useMoonPaySource()
            } else {
                merchant.reloadMethods()
            }
        }
    }

    private func reloadActive() {
        guard !isConnecting else { return }
        active.reloadMethods()
    }

    private var isMoonPayActive: Bool {
        moonPay.map { $0 === active } ?? false
    }

    func useMoonPaySource() {
        guard let moonPay, !isMoonPayActive else { return }
        switchSource(to: moonPay, from: merchant)
    }

    func useMerchantSource() {
        guard let moonPay, isMoonPayActive else { return }
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

    private func loadCurrencies() async {
        let loaded: [RemoteCurrency]
        do {
            loaded = try await currenciesService.loadCurrencies()
        } catch {
            return
        }
        let fiat = loaded.filter { $0.currencyType == .fiat }
        guard !fiat.isEmpty else { return }
        currencies = fiat
        let selected = fiat.first { $0.code == currencyStore.state.code } ?? currentCurrency
        guard fiat.contains(where: { $0.code == selected.code }) else { return }
        let changed = selected.code != currentCurrency.code
        currentCurrency = selected
        applyCurrency(selected)
        if changed {
            reloadActive()
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
        onSelectAsset?(currentCurrency.code)
    }

    private func applyAssetIcon() {
        if let asset, let url = URL(string: asset.asset.image), !asset.asset.image.isEmpty {
            amountViewModel.convertedLeadingImage = nil
            amountViewModel.convertedLeadingImageURL = url
        } else {
            amountViewModel.convertedLeadingImageURL = nil
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

    fileprivate nonisolated static func assetLabel(for asset: MultichainAsset?) -> String {
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

    private static func quickOptionTitle(_ amount: Int, currency: RemoteCurrency) -> String {
        withSymbol(String(amount), currency: currency)
    }

    func formatLimit(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "\u{00A0}"
        let amount = formatter.string(from: value as NSDecimalNumber) ?? NSDecimalNumber(decimal: value).stringValue
        return Self.withSymbol(amount, currency: currentCurrency)
    }

    private static func formatFiat(_ value: Decimal, currency: RemoteCurrency) -> String {
        withSymbol(formatRate(value), currency: currency)
    }

    private static func withSymbol(_ amount: String, currency: RemoteCurrency) -> String {
        let legacy = currency.legacyCurrency
        if legacy.symbolOnLeft {
            return "\(legacy.symbol)\(amount)"
        }
        return "\(amount) \(legacy.symbol)"
    }

    private static func formatRate(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        if value < 1 {
            formatter.usesSignificantDigits = true
            formatter.minimumSignificantDigits = 1
            formatter.maximumSignificantDigits = 4
        } else {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 3
        }
        return formatter.string(from: value as NSDecimalNumber) ?? NSDecimalNumber(decimal: value).stringValue
    }

    /// Not zero: `AmountInputSwiftUIViewModel` divides by the rate when the destination unit changes.
    private static let emptyRate = NSDecimalNumber(mantissa: 1, exponent: -30, isNegative: false)
    private static let defaultQuickAmounts = [50, 100, 500]

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

    func applyRate(_ rate: Decimal?) {
        guard let rate, rate > 0 else {
            quoteRate = nil
            amountViewModel.rate = Self.emptyRate
            return
        }
        quoteRate = rate
        amountViewModel.rate = NSDecimalNumber(decimal: rate)
    }

    func setConvertedShimmering(_ isOn: Bool) {
        amountViewModel.isConvertedShimmering = isOn
    }

    func restartRateTimer() {
        rateRestartToken += 1
    }

    func reportFailure(_ error: Error) {
        if case MultichainRampAPIError.cancelled = error { return }
        onFailure?(TKLocales.Errors.unknown)
    }

    /// The chosen asset cannot be bought in this currency: once per currency, switch to the asset the
    /// currency offers by default, and show the placeholder only if there is none.
    func didFindNoPaymentMethods() {
        guard assetFallbackCurrencyCode != currentCurrency.code else { return }
        assetFallbackCurrencyCode = currentCurrency.code
        let code = currentCurrency.code
        let emptyAssetId = asset?.asset.assetId
        defaultAssetTask?.cancel()
        isLoadingDefaultAsset = true
        defaultAssetTask = Task { [weak self] in
            let candidate = try? await self?.loadDefaultAsset(code)
            guard let self, !Task.isCancelled else { return }
            isLoadingDefaultAsset = false
            guard code == currentCurrency.code,
                  asset?.asset.assetId == emptyAssetId,
                  let candidate,
                  candidate.asset.assetId != emptyAssetId
            else { return }
            setAsset(candidate)
        }
    }

    func fallBackToMerchant() {
        useMerchantSource()
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
