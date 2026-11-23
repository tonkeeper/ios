import AppUI
import BigInt
import Combine
import Foundation
import KeeperCore
import TKLocalize

@MainActor
final class MerchantRampSource: ObservableObject, RampDataSource {
    var onSelectPaymentMethod: (([RampPaymentMethodRow], String?) -> Void)?
    /// Continue goes to the merchant: its page is requested now.
    var onContinue: (() -> Void)?
    /// The merchant's page and our id of the attempt, the quote's `merchantTransactionId`.
    var onOpenMerchant: ((URL, String) -> Void)?
    var onOpenP2P: ((MultichainAsset, String) -> Void)?

    weak var host: RampDataSourceHost?

    @Published private var paymentRows: [RampPaymentMethodRow] = []
    @Published private var selectedMethodType: String?
    @Published private(set) var selectedMerchantId: String?
    /// The merchant the user picked; without one, the merchant with the best rate for the amount.
    @Published private(set) var preferredMerchant: (id: String, title: String)?
    @Published private var quotes: InsertAmountQuotesState?
    @Published private var calculatedAmount: BigUInt?
    @Published private var isContinueLoading = false
    @Published private(set) var isLoadingMethods = false
    @Published private var isAssetNotSold = false

    private let service: RampMerchantService
    private var assetDetail: OnRampAssetDetail?
    /// The method types our backend lists MoonPay's widget for in the loaded currency; nil until
    /// the methods load.
    private var moonPayWidgetMethodTypes: Set<String>?
    /// The asset and currency `moonPayWidgetMethodTypes` were loaded for: a reload of the same
    /// keeps them, so MoonPay stays the provider while the methods load again or fail to.
    private var moonPayWidgetScope: String?
    private var providers: [OnRampProvider] = []
    private var merchants: [OnRampMerchantInfo] = []
    private var areMerchantsReady = false
    private var methodsTask: Task<Void, Never>?
    private var merchantsTask: Task<Void, Never>?
    private var quoteTask: Task<Void, Never>?

    init(service: RampMerchantService) {
        self.service = service
    }

    deinit {
        methodsTask?.cancel()
        merchantsTask?.cancel()
        quoteTask?.cancel()
    }

    // MARK: - RampDataSource

    var payment: MoonPayRampViewState.Payment {
        guard let row = paymentRows.first(where: { $0.type == selectedMethodType }) else {
            return .init(title: "—", subtitle: "", iconURL: nil)
        }
        let logo = selectedMerchantId
            .flatMap { id in merchants.first { $0.id == id } }
            .flatMap { URL(string: $0.image) }
        return .init(title: row.title, subtitle: row.subtitle ?? "", iconURL: row.imageURL, badge: logo.map { .url($0) })
    }

    /// The asset is not sold in the currency: our backend lists no method for it, or does not
    /// know it (404). The screen keeps the asset the user came for and shows its stub.
    var hasNoPaymentMethods: Bool {
        isAssetNotSold || (assetDetail != nil && paymentRows.isEmpty)
    }

    var analyticsMethod: String? {
        isP2PSelected ? nil : selectedMethodType
    }

    /// A quote named the merchant with the best rate, or the user picked one.
    var isMerchantKnown: Bool {
        preferredMerchant != nil || selectedMerchantId != nil
    }

    /// The amount is out of the merchant's limits: Continue, disabled, names the limit.
    var actionTitle: String? {
        guard !isP2PSelected, let host,
              let violation = limits.violation(merchantId: selectedMerchantId, amount: fiatAmount)
        else { return nil }
        switch violation {
        case let .belowMin(value):
            return TKLocales.Ramp.Moonpay.Limit.minAmount(host.formatLimit(value))
        case let .aboveMax(value):
            return TKLocales.Ramp.Moonpay.Limit.maxAmount(host.formatLimit(value))
        }
    }

    var isActionEnabled: Bool {
        isP2PSelected ? host?.asset != nil : canContinue
    }

    var isActionLoading: Bool {
        isContinueLoading
    }

    var canRefreshQuote: Bool {
        areMerchantsReady
            && assetDetail != nil
            && !isContinueLoading
            && !isP2PSelected
            && fiatAmount > 0
            && limits.hasServiceableMerchant(amount: fiatAmount)
    }

    /// Our backend lists MoonPay's widget for the asset and currency: before the sign-in, MoonPay
    /// can be bought through only there. False until the methods load.
    var listsMoonPayWidget: Bool {
        moonPayWidgetMethodTypes?.isEmpty == false
    }

    /// The selected method is listed now and is one MoonPay's widget takes, so the sign-in to the
    /// native MoonPay may serve it. False while the methods reload or after their load failed.
    var selectedMethodTakesMoonPayWidget: Bool {
        guard assetDetail != nil, paymentRows.contains(where: { $0.type == selectedMethodType }) else { return false }
        return RampMerchantService.moonPayWidgetTakes(methodType: selectedMethodType, among: moonPayWidgetMethodTypes)
    }

    /// Takes effect with the next `reloadMethods`.
    func selectMerchant(_ merchant: (id: String, title: String)?) {
        preferredMerchant = merchant
    }

    /// The merchant Continue goes to. Before an amount is entered none is selected, and the
    /// merchant first in our backend's order stands for it.
    var currentMerchantId: String? {
        preferredMerchant?.id ?? selectedMerchantId ?? limits.orderedMerchantIds.first
    }

    var currentMerchantTitle: String? {
        if let preferredMerchant { return preferredMerchant.title }
        return currentMerchantId.flatMap { id in merchants.first { $0.id == id }?.title }
    }

    func reloadMethods() {
        methodsTask?.cancel()
        merchantsTask?.cancel()
        host?.setLoadingMinimum(false)
        areMerchantsReady = false
        providers = []
        merchants = []
        assetDetail = nil
        paymentRows = []
        isAssetNotSold = false
        resetQuoteState()
        isLoadingMethods = false
        let scope = host?.asset.map { Self.moonPayWidgetScope(assetId: $0.asset.assetId, fiat: host?.fiatCode ?? "") }
        if scope == nil || scope != moonPayWidgetScope {
            clearMoonPayWidgetMethods()
        }
        guard let host, let asset = host.asset else { return }
        let fiat = host.fiatCode
        let assetId = asset.asset.assetId
        isLoadingMethods = true
        methodsTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await service.methods(asset: asset, fiat: fiat)
                guard !Task.isCancelled, fiat == host.fiatCode, host.asset?.asset.assetId == assetId else { return }
                isLoadingMethods = false
                // Set before the rows: whether MoonPay is the provider, and so which rows are
                // listed, depends on where the backend lists MoonPay's widget.
                moonPayWidgetMethodTypes = RampMerchantService.moonPayWidgetMethodTypes(in: result.detail, fiat: fiat)
                moonPayWidgetScope = Self.moonPayWidgetScope(assetId: assetId, fiat: fiat)
                let hadPick = preferredMerchant != nil
                let rows = rows(of: result, fiat: fiat)
                if hadPick, preferredMerchant == nil, host.merchantPickDidDrop() { return }
                assetDetail = result.detail
                paymentRows = rows
                guard !paymentRows.isEmpty else { return }
                let current = selectedMethodType
                if !paymentRows.contains(where: { $0.type == current }) {
                    selectedMethodType = paymentRows.first { !$0.isP2P }?.type ?? paymentRows.first?.type
                }
                loadMerchants()
            } catch MultichainRampAPIError.notFound {
                guard !Task.isCancelled, fiat == host.fiatCode, host.asset?.asset.assetId == assetId else { return }
                isLoadingMethods = false
                // A connected MoonPay that sells the asset takes the screen back, as when MoonPay
                // only failed to load. The 404 says nothing about a picked merchant: the pick goes
                // only with that hand-over.
                let pick = preferredMerchant
                preferredMerchant = nil
                if host.merchantsDoNotSell() { return }
                preferredMerchant = pick
                isAssetNotSold = true
            } catch {
                guard !Task.isCancelled else { return }
                isLoadingMethods = false
                host.reportFailure(error)
            }
        }
    }

    func selectMethod(_ type: String) {
        selectedMethodType = type
        loadMerchants()
    }

    func amountDidChange() {
        scheduleQuote()
    }

    func refreshQuote() {
        scheduleQuote(refreshing: true)
    }

    func tapPaymentMethod() {
        onSelectPaymentMethod?(paymentRows, selectedMethodType)
    }

    func tapAction() {
        guard !isP2PSelected else {
            openP2P()
            return
        }
        guard canContinue,
              let host,
              let detail = assetDetail,
              let type = selectedMethodType,
              let quote = selectedQuote
        else { return }
        let amount = RampDataSourceDefaults.decimalString(fiatAmount, fractionDigits: host.fractionDigits)
        let fiat = host.fiatCode
        onContinue?()
        isContinueLoading = true
        quoteTask?.cancel()
        Task { [weak self] in
            guard let self else { return }
            defer {
                isContinueLoading = false
                host.restartRateTimer()
            }
            var attempt = 0
            while true {
                do {
                    let url = try await service.widgetURL(
                        detail: detail,
                        amount: amount,
                        fiat: fiat,
                        methodType: type,
                        quote: quote
                    )
                    onOpenMerchant?(url, quote.merchantTransactionId)
                    return
                } catch MultichainRampAPIError.cancelled where attempt < 1 && !Task.isCancelled {
                    attempt += 1
                } catch {
                    host.reportFailure(error)
                    return
                }
            }
        }
    }

    func deactivate() {
        host?.setLoadingMinimum(false)
        methodsTask?.cancel()
        merchantsTask?.cancel()
        quoteTask?.cancel()
        areMerchantsReady = false
        providers = []
        merchants = []
        assetDetail = nil
        clearMoonPayWidgetMethods()
        paymentRows = []
        selectedMethodType = nil
        quotes = nil
        selectedMerchantId = nil
        calculatedAmount = nil
        isContinueLoading = false
    }

    // MARK: - Private

    private func openP2P() {
        guard let host, let asset = host.asset else { return }
        onOpenP2P?(asset, host.fiatCode)
    }

    private var fiatAmount: BigUInt {
        host?.fiatAmount ?? 0
    }

    var isP2PSelected: Bool {
        paymentRows.first { $0.type == selectedMethodType }?.isP2P == true
    }

    private var limits: RampLimitsEvaluator {
        RampLimitsEvaluator(
            fractionalDigits: host?.fractionDigits ?? 0,
            providers: providers,
            merchantIds: merchants.map(\.id),
            quotes: quotes
        )
    }

    private var selectedQuote: InsertAmountMerchantQuote? {
        selectedMerchantId.flatMap { limits.quote(for: $0) }
    }

    private var canContinue: Bool {
        guard limits.violation(merchantId: selectedMerchantId, amount: fiatAmount) == nil,
              !isContinueLoading,
              fiatAmount > 0,
              fiatAmount == calculatedAmount,
              let quote = selectedQuote
        else { return false }
        return quote.convertedAmount > 0
    }

    /// The picked merchant's methods only, P2P aside; a merchant that does not sell the asset in
    /// this currency is dropped for the best rate again.
    private func rows(of result: RampMerchantMethods, fiat: String) -> [RampPaymentMethodRow] {
        guard let preferredMerchant else { return moonPayRows(of: result, fiat: fiat) }
        let types = RampMerchantService.methodTypes(of: preferredMerchant.id, in: result.detail, fiat: fiat)
        guard !types.isEmpty else {
            self.preferredMerchant = nil
            return moonPayRows(of: result, fiat: fiat)
        }
        return result.rows.filter { $0.isP2P || types.contains($0.type) }
    }

    /// All rows, or before the sign-in to the native MoonPay, MoonPay's widget's when it has any.
    private func moonPayRows(of result: RampMerchantMethods, fiat: String) -> [RampPaymentMethodRow] {
        guard host?.listsMoonPayWidgetMethods == true else { return result.rows }
        guard let types = moonPayWidgetMethodTypes, !types.isEmpty else { return result.rows }
        return result.rows.filter { $0.isP2P || types.contains($0.type) }
    }

    private func clearMoonPayWidgetMethods() {
        moonPayWidgetMethodTypes = nil
        moonPayWidgetScope = nil
    }

    private static func moonPayWidgetScope(assetId: String, fiat: String) -> String {
        "\(assetId)|\(fiat)"
    }

    private func merchantId(for amount: BigUInt) -> String? {
        if let preferredMerchant, merchants.contains(where: { $0.id == preferredMerchant.id }) {
            return preferredMerchant.id
        }
        return limits.bestMerchantId(amount: amount)
    }

    private func resetQuoteState() {
        quoteTask?.cancel()
        quotes = nil
        selectedMerchantId = nil
        calculatedAmount = nil
        host?.applyRate(nil)
        host?.setConvertedShimmering(false)
    }

    private func loadMerchants() {
        merchantsTask?.cancel()
        areMerchantsReady = false
        providers = []
        merchants = []
        resetQuoteState()
        guard let host, let detail = assetDetail, let type = selectedMethodType, !isP2PSelected else {
            host?.setLoadingMinimum(false)
            return
        }
        let fiat = host.fiatCode
        host.setLoadingMinimum(true)
        merchantsTask = Task { [weak self] in
            guard let self else { return }
            do {
                let context = try await service.merchants(detail: detail, methodType: type, fiat: fiat)
                guard !Task.isCancelled else { return }
                providers = context.providers
                merchants = context.merchants
                areMerchantsReady = true
                selectedMerchantId = merchantId(for: fiatAmount)
                suggestMinimumAmount()
                scheduleQuote()
            } catch {
                guard !Task.isCancelled else { return }
                host.setLoadingMinimum(false)
                host.reportFailure(error)
            }
        }
    }

    private func suggestMinimumAmount() {
        guard let host else { return }
        defer { host.setLoadingMinimum(false) }
        guard let min = selectedMerchantId.flatMap({ limits.limits(for: $0)?.min }),
              let amount = Decimal(string: "\(min)", locale: Locale(identifier: "en_US_POSIX"))
        else { return }
        host.applyMinimumAmount(amount)
    }

    private func scheduleQuote(refreshing: Bool = false) {
        quoteTask?.cancel()
        if !refreshing {
            calculatedAmount = nil
        }
        guard areMerchantsReady, let host else { return }
        guard fiatAmount > 0 else {
            quotes = nil
            selectedMerchantId = nil
            host.applyRate(nil)
            host.setConvertedShimmering(false)
            return
        }
        guard limits.hasServiceableMerchant(amount: fiatAmount) else {
            selectedMerchantId = merchantId(for: fiatAmount)
            host.applyRate(nil)
            host.setConvertedShimmering(false)
            return
        }
        guard let detail = assetDetail, let type = selectedMethodType else { return }
        let requested = fiatAmount
        let amount = RampDataSourceDefaults.decimalString(requested, fractionDigits: host.fractionDigits)
        let fiat = host.fiatCode
        if !refreshing {
            host.setConvertedShimmering(true)
        }
        quoteTask = Task { [weak self] in
            if !refreshing {
                try? await Task.sleep(nanoseconds: RampDataSourceDefaults.quoteDebounce)
            }
            guard let self, !Task.isCancelled else { return }
            do {
                let state = try await service.quotes(detail: detail, amount: amount, fiat: fiat, methodType: type)
                guard !Task.isCancelled, requested == fiatAmount else { return }
                quotes = state
                calculatedAmount = requested
                let chosen = merchantId(for: requested)
                selectedMerchantId = chosen
                host.setConvertedShimmering(false)
                applyRate(for: chosen, amount: requested)
                host.restartRateTimer()
            } catch {
                guard !Task.isCancelled else { return }
                host.setConvertedShimmering(false)
                if refreshing {
                    host.restartRateTimer()
                }
                if refreshing {
                    host.reportQuoteFailure(error)
                } else {
                    host.reportFailure(error)
                }
            }
        }
    }

    private func applyRate(for merchantId: String?, amount: BigUInt) {
        guard let merchantId,
              limits.canServe(merchantId: merchantId, amount: amount),
              let quote = limits.quote(for: merchantId)
        else {
            host?.applyRate(nil)
            return
        }
        let serverRate = quote.rate.flatMap { $0 > 0 ? $0 : nil }
        let derivedRate = quote.amountIn.flatMap { $0 > 0 && quote.convertedAmount > 0 ? quote.convertedAmount / $0 : nil }
        host?.applyRate(serverRate ?? derivedRate)
    }
}
