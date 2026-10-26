import AppUI
import BigInt
import Combine
import Foundation
import KeeperCore

@MainActor
final class MerchantRampSource: ObservableObject, RampDataSource {
    var onSelectPaymentMethod: (([RampPaymentMethodRow], String?) -> Void)?
    var onOpenMerchant: ((URL) -> Void)?
    var onOpenP2P: ((MultichainAsset, String) -> Void)?

    weak var host: RampDataSourceHost?

    @Published private var paymentRows: [RampPaymentMethodRow] = []
    @Published private var selectedMethodType: String?
    @Published private var selectedMerchantId: String?
    @Published private var quotes: InsertAmountQuotesState?
    @Published private var calculatedAmount: BigUInt?
    @Published private var isContinueLoading = false
    @Published private(set) var isLoadingMethods = false

    private let service: RampMerchantService
    private var assetDetail: OnRampAssetDetail?
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
        return .init(title: row.title, subtitle: row.subtitle, iconURL: row.imageURL, badgeURL: logo)
    }

    var limitText: String? {
        guard !isP2PSelected else { return nil }
        return limits.violation(merchantId: selectedMerchantId, amount: fiatAmount)?.message
    }

    var hasNoPaymentMethods: Bool {
        assetDetail != nil && paymentRows.isEmpty
    }

    var actionTitle: String? {
        nil
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

    func reloadMethods() {
        methodsTask?.cancel()
        merchantsTask?.cancel()
        host?.setLoadingMinimum(false)
        areMerchantsReady = false
        providers = []
        merchants = []
        assetDetail = nil
        paymentRows = []
        resetQuoteState()
        isLoadingMethods = false
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
                assetDetail = result.detail
                paymentRows = result.rows
                if result.rows.isEmpty {
                    host.didFindNoPaymentMethods()
                    return
                }
                let current = selectedMethodType
                if !result.rows.contains(where: { $0.type == current }) {
                    selectedMethodType = result.rows.first { !$0.isP2P }?.type ?? result.rows.first?.type
                }
                loadMerchants()
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
                    onOpenMerchant?(url)
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
        paymentRows = []
        selectedMethodType = nil
        quotes = nil
        selectedMerchantId = nil
        calculatedAmount = nil
        isContinueLoading = false
    }

    func openP2P() {
        guard let host, let asset = host.asset else { return }
        onOpenP2P?(asset, host.fiatCode)
    }

    // MARK: - Private

    private var fiatAmount: BigUInt {
        host?.fiatAmount ?? 0
    }

    private var isP2PSelected: Bool {
        paymentRows.first { $0.type == selectedMethodType }?.isP2P == true
    }

    private var limits: RampLimitsEvaluator {
        RampLimitsEvaluator(
            fractionalDigits: host?.fractionDigits ?? 0,
            currencyCode: host?.fiatCode ?? "",
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
                selectedMerchantId = limits.bestMerchantId(amount: fiatAmount)
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
            selectedMerchantId = limits.bestMerchantId(amount: fiatAmount)
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
                let best = limits.bestMerchantId(amount: requested)
                selectedMerchantId = best
                host.setConvertedShimmering(false)
                applyRate(for: best, amount: requested)
                host.restartRateTimer()
            } catch {
                guard !Task.isCancelled else { return }
                host.setConvertedShimmering(false)
                if refreshing {
                    host.restartRateTimer()
                }
                host.reportFailure(error)
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
