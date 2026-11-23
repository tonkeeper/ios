import AppUI
import BigInt
import Combine
import Foundation
import KeeperCore
import MoonPay
import TKAppInfo
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

enum MoonPayConnectionCheck: Equatable {
    case connected
    /// MoonPay takes the customer once they sign in.
    case signInRequired
    case unavailable
}

@MainActor
final class MoonPayRampSource: ObservableObject, RampDataSource {
    var onSelectPaymentMethod: (([RampPaymentMethodRow], String?, [MoonPaySavedCard], String?) -> Void)?
    var onAddCard: (() -> Void)?
    var onChallenge: ((URL) -> Void)?
    var onContinue: ((MoonPayBuyQuote, String) -> Void)?
    /// The Apple Pay button was tapped, which started the payment whose updates are passed.
    /// The quote, the method's title, the payment's updates and our id of the payment.
    var onApplePayPressed: ((MoonPayBuyQuote, String, AsyncStream<MoonPayPaymentUpdate>, String) -> Void)?
    var onOpenP2P: ((MultichainAsset, String) -> Void)?

    weak var host: RampDataSourceHost?

    @Published private var paymentRows: [RampPaymentMethodRow] = []
    @Published private var selectedMethodType: String?
    @Published private var calculatedAmount: BigUInt?
    @Published private var limitMessage: String?
    var isLoadingMethods: Bool {
        isFetchingMethods || awaitsQuotability
    }

    @Published private var isFetchingMethods = false
    /// A DeFi token may still turn out unquotable: the methods stay a skeleton until the minimum
    /// probe or a quote tells, so none flashes before the merchants take over.
    @Published private var awaitsQuotability = false
    @Published private var isRefreshingQuoteForContinue = false
    @Published private var applePayButton: MoonPayApplePayButton?

    private let service: MoonPayRampService
    private let addressForAsset: (MultichainAsset) -> String?
    private let loadP2PMethod: (MultichainAsset, String) async throws -> RampPaymentMethodRow?
    private var methods: MoonPayPaymentMethods?
    /// Cards deleted here; a methods request that started before the delete may still list them.
    private var deletedCardIDs: Set<String> = []
    /// Cards whose delete request is running; a payment method screen opened meanwhile hides their menu.
    private(set) var removingCardIDs: Set<String> = []
    private var quote: MoonPayBuyQuote?
    /// The last quote's: they follow the region, asset and method, not the amount, so they stay
    /// while the next amount is quoted and go only with what they depend on.
    private var disclosures: [MoonPayBuyQuote.PaymentDisclosure] = []
    private var destinationAsset: MoonPayAsset?
    private var selectedCardID: String?
    private var usesNewCard = false
    private var methodsTask: Task<Void, Never>?
    /// Currencies MoonPay had no method for while the screen is open. Its methods depend on the
    /// currency, not the asset, so another asset in one of them goes straight to the merchants.
    private var currenciesWithoutMethods: Set<String> = []
    private var assetsNotSold: Set<String> = []
    /// Assets MoonPay quoted while the screen is open: a 503 for one of them later is an outage.
    private var assetsQuoted: Set<String> = []
    /// Assets whose minimum probe MoonPay answered with a quote or an amount limit: they are
    /// quotable, so a later method pick does not hold the screen for them again.
    private var assetsProbed: Set<String> = []
    private var quoteTask: Task<Void, Never>?
    private var minimumTask: Task<Void, Never>?
    private var applePayButtonTask: Task<Void, Never>?
    private var quoteFreshnessTask: Task<Void, Never>?
    /// The button's failures are reported once per method and amount; retries stay silent.
    private var didReportApplePayFailure = false
    /// Cleared by the next quote, which retries the button.
    @Published private var isApplePayButtonFailed = false

    init(
        service: MoonPayRampService,
        addressForAsset: @escaping (MultichainAsset) -> String?,
        loadP2PMethod: @escaping (MultichainAsset, String) async throws -> RampPaymentMethodRow?
    ) {
        self.service = service
        self.addressForAsset = addressForAsset
        self.loadP2PMethod = loadP2PMethod
    }

    deinit {
        methodsTask?.cancel()
        quoteTask?.cancel()
        minimumTask?.cancel()
        applePayButtonTask?.cancel()
        quoteFreshnessTask?.cancel()
    }

    // MARK: - RampDataSource

    var payment: MoonPayRampViewState.Payment {
        guard let row = paymentRows.first(where: { $0.type == selectedMethodType }) else {
            return .init(title: "—", subtitle: "", iconURL: nil)
        }
        if isCardSelected,
           let id = effectiveCardID,
           let card = methods?.stored.first(where: { $0.id == id })
        {
            let presentation = MoonPayCardPresentation(card)
            return .init(
                title: presentation.title,
                subtitle: presentation.subtitle,
                iconURL: nil,
                savedCard: MoonPaySavedCardIcon(brand: presentation.brand, last4: presentation.last4),
                badge: .moonPay
            )
        }
        // P2P goes through P2P Express, not MoonPay, so it has no provider badge.
        return .init(title: row.title, subtitle: row.subtitle ?? "", iconURL: row.imageURL, badge: row.isP2P ? nil : .moonPay)
    }

    func mayTake(currency code: String) -> Bool {
        !currenciesWithoutMethods.contains(code.uppercased())
    }

    /// False once MoonPay was found not to sell the asset.
    func maySell(assetId: String) -> Bool {
        !assetsNotSold.contains(assetId)
    }

    /// The titles of MoonPay's methods for the provider sheet: the loaded ones, or before they are
    /// loaded, such as before the sign-in, the ones our backend describes.
    /// `cachedOnly` does not ask our backend for the descriptions not loaded yet.
    func methodTitles(cachedOnly: Bool = false) async -> [String] {
        let loaded = paymentRows.filter { !$0.isP2P }.map(\.title)
        guard loaded.isEmpty else { return loaded }
        let info = cachedOnly ? service.cachedPaymentMethodInfoList ?? [] : await service.paymentMethodInfoList()
        return info
            .filter { !Self.unsupportedTypes.contains($0.type) }
            .map(\.title)
    }

    var isConnected: Bool {
        service.isConnected
    }

    /// Connects without presenting MoonPay's sign-in.
    func checkConnection() async -> MoonPayConnectionCheck {
        do {
            _ = try await service.ensureConnected(interactive: false)
            return .connected
        } catch MoonPayRampError.signInRequired {
            return .signInRequired
        } catch {
            Log.multichainRamp.w("moonpay connection failed, using merchants", error: error)
            return .unavailable
        }
    }

    /// Presents MoonPay's sign-in where the customer has to sign in.
    func signIn() async throws {
        _ = try await service.ensureConnected()
    }

    /// Never: with no MoonPay method the screen falls back to the merchants, whose empty state
    /// is the one shown.
    var hasNoPaymentMethods: Bool {
        false
    }

    var actionTitle: String? {
        limitMessage
    }

    /// P2P opens our market, not MoonPay.
    var paymentDisclosures: [MoonPayBuyQuote.PaymentDisclosure] {
        isP2PSelected ? [] : disclosures
    }

    /// Only for the amount typed: a quote of the previous one would show other fees.
    var priceQuote: MoonPayBuyQuote? {
        isP2PSelected || !isQuoteCurrent ? nil : quote
    }

    var isActionEnabled: Bool {
        guard host?.asset != nil else { return false }
        if isP2PSelected { return true }
        guard limitMessage == nil else { return false }
        if isCardSelected, effectiveCardID == nil { return true }
        guard isQuoteCurrent else { return false }
        // Apple Pay is paid from its button frame; Continue only opens the challenge a quote may need.
        return !isApplePaySelected || quote?.executable == false
    }

    var inlineAction: RampInlineAction? {
        if let applePayButton, applePayButton.isPressed {
            return RampInlineAction(controller: applePayButton.controller, isReady: true, isEnabled: false)
        }
        guard isApplePaySelected,
              limitMessage == nil,
              quote?.executable != false,
              !isApplePayButtonFailed,
              applePayButton != nil || fiatAmount > 0
        else { return nil }
        return RampInlineAction(
            controller: applePayButton?.controller,
            isReady: applePayButton?.isReady == true,
            isEnabled: isQuoteCurrent && quote?.isFresh(for: Self.minimumRemainingLifetime) == true
        )
    }

    var isActionLoading: Bool {
        isRefreshingQuoteForContinue
    }

    var canRefreshQuote: Bool {
        quote != nil && fiatAmount > 0 && !isRefreshingQuoteForContinue
    }

    func reloadMethods() {
        methodsTask?.cancel()
        minimumTask?.cancel()
        resetQuoteState()
        isFetchingMethods = false
        awaitsQuotability = false
        guard let host else { return }
        host.setLoadingMinimum(false)
        let fiat = host.fiatCode
        let asset = host.asset
        let assetDetails = asset?.asset
        isFetchingMethods = true
        methodsTask = Task { [weak self] in
            guard let self else { return }
            do {
                async let loadedMethods = service.paymentMethods(fiat: fiat)
                async let loadedDestination = resolveDestination(of: assetDetails)
                async let loadedInfo = service.paymentMethodInfo()
                async let loadedP2P = p2pMethod(asset: asset, fiat: fiat)
                let methods = try await loadedMethods
                let destination = try await loadedDestination
                let info = await loadedInfo
                let p2p = await loadedP2P
                guard !Task.isCancelled else { return }
                if let assetDetails, destination == nil, host.asset?.asset.assetId == assetDetails.assetId {
                    assetsNotSold.insert(assetDetails.assetId)
                    isFetchingMethods = false
                    host.fallBackToMerchant()
                    return
                }
                guard !Task.isCancelled, fiat == host.fiatCode, host.asset?.asset.assetId == assetDetails?.assetId else { return }
                awaitsQuotability = assetDetails.map { self.mayBeUnquotable(destination, assetId: $0.assetId) } ?? false
                isFetchingMethods = false
                destinationAsset = destination
                self.methods = withoutDeletedCards(methods)
                let rows = methods.activeConfigs
                    .filter { $0.supportsBuy && !Self.unsupportedTypes.contains($0.type) }
                    .map { Self.row(for: $0, info: info[$0.type]) }
                // MoonPay does not take this currency. Our backend may still sell it through other
                // providers.
                if rows.isEmpty {
                    currenciesWithoutMethods.insert(fiat.uppercased())
                    host.fallBackToMerchant()
                    return
                }
                let allRows = rows + (p2p.map { [$0] } ?? [])
                paymentRows = allRows
                let current = selectedMethodType
                if !rows.contains(where: { $0.type == current }) {
                    selectedMethodType = rows.first?.type ?? p2p?.type
                }
                suggestMinimumAmount()
                scheduleQuote()
            } catch {
                guard !Task.isCancelled else { return }
                isFetchingMethods = false
                host.fallBackToMerchant()
            }
        }
    }

    /// P2P is not a MoonPay method: it comes from our backend and opens P2P Express without a quote,
    /// so a failure only hides it.
    private func p2pMethod(asset: MultichainAsset?, fiat: String) async -> RampPaymentMethodRow? {
        guard let asset else { return nil }
        do {
            return try await loadP2PMethod(asset, fiat)
        } catch {
            Log.multichainRamp.w("p2p method for moonpay ramp failed to load", error: error)
            return nil
        }
    }

    private func resolveDestination(of details: MultichainAssetDetails?) async throws -> MoonPayAsset? {
        guard let details else { return nil }
        return try await service.destinationAsset(for: details)
    }

    func selectMethod(_ type: String) {
        if type != selectedMethodType { disclosures = [] }
        removeApplePayButton()
        selectedMethodType = type
        if type == Self.cardType {
            usesNewCard = true
            selectedCardID = nil
        }
        suggestMinimumAmount()
        scheduleQuote()
    }

    func selectSavedCard(_ id: String) {
        if selectedMethodType != Self.cardType { disclosures = [] }
        removeApplePayButton()
        selectedMethodType = Self.cardType
        selectedCardID = id
        usesNewCard = false
        suggestMinimumAmount()
        scheduleQuote()
    }

    func cardAdded(_ card: MoonPaySavedCard) {
        reloadMethods()
        selectSavedCard(card.id)
    }

    /// MoonPay may not let a customer delete cards; unknown capabilities do not forbid it.
    var canDeleteCards: Bool {
        methods?.configs.first { $0.type == Self.cardType }?.capabilities?.allowsDeletion ?? true
    }

    /// Deletes the card on MoonPay, then drops it here. A selected card falls back to the next
    /// active one, so the quote is requested again.
    func deleteCard(_ id: String) async throws {
        removingCardIDs.insert(id)
        defer { removingCardIDs.remove(id) }
        try await service.deleteCard(id: id)
        deletedCardIDs.insert(id)
        guard let methods else { return }
        let wasInUse = isCardSelected && effectiveCardID == id
        objectWillChange.send()
        self.methods = withoutDeletedCards(methods)
        if selectedCardID == id {
            selectedCardID = nil
        }
        guard wasInUse else { return }
        suggestMinimumAmount()
        scheduleQuote()
    }

    private func withoutDeletedCards(_ methods: MoonPayPaymentMethods) -> MoonPayPaymentMethods {
        guard methods.stored.contains(where: { deletedCardIDs.contains($0.id) }) else { return methods }
        return MoonPayPaymentMethods(configs: methods.configs, stored: methods.stored.filter { !deletedCardIDs.contains($0.id) })
    }

    func amountDidChange() {
        didReportApplePayFailure = false
        scheduleQuote()
    }

    func refreshQuote() {
        guard !isRefreshingQuoteForContinue else { return }
        scheduleQuote(refreshing: true)
    }

    /// The name the picker shows for a MoonPay method type.
    func title(forMethodType type: String) -> String {
        paymentRows.first { $0.type == type }?.title ?? Self.fallbackTitle(for: type)
    }

    func tapPaymentMethod() {
        onSelectPaymentMethod?(
            paymentRows,
            selectedMethodType,
            methods?.stored ?? [],
            isCardSelected ? effectiveCardID : nil
        )
    }

    func tapAction() {
        if isP2PSelected {
            guard let host, let asset = host.asset else { return }
            onOpenP2P?(asset, host.fiatCode)
            return
        }
        if isCardSelected, effectiveCardID == nil {
            onAddCard?()
            return
        }
        guard let quote else { return }
        guard quote.executable else {
            if let url = quote.challengeURL {
                onChallenge?(url)
            }
            return
        }
        guard !isApplePaySelected else { return }
        guard quote.isFresh(for: Self.minimumRemainingLifetime) else {
            refreshQuoteAndContinue()
            return
        }
        onContinue?(quote, payment.title)
    }

    func deactivate() {
        disclosures = []
        removeApplePayButton()
        isFetchingMethods = false
        awaitsQuotability = false
        minimumTask?.cancel()
        isRefreshingQuoteForContinue = false
        host?.setLoadingMinimum(false)
        methodsTask?.cancel()
        quoteTask?.cancel()
        methods = nil
        quote = nil
        destinationAsset = nil
        paymentRows = []
        selectedMethodType = nil
        selectedCardID = nil
        usesNewCard = false
        calculatedAmount = nil
        limitMessage = nil
    }

    // MARK: - Private

    private static let cardType = "card"
    private static let applePayType = "apple_pay"
    private static let unsupportedTypes: Set<String> = ["google_pay"]

    private var fiatAmount: BigUInt {
        host?.fiatAmount ?? 0
    }

    private var isCardSelected: Bool {
        selectedMethodType == Self.cardType
    }

    private var isApplePaySelected: Bool {
        selectedMethodType == Self.applePayType
    }

    private var isQuoteCurrent: Bool {
        quote != nil && fiatAmount > 0 && fiatAmount == calculatedAmount
    }

    private var isP2PSelected: Bool {
        paymentRows.first { $0.type == selectedMethodType }?.isP2P == true
    }

    var analyticsMethod: String? {
        guard let type = selectedMethodType, !isP2PSelected else { return nil }
        if type == Self.cardType, effectiveCardID != nil { return BuyCryptoAnalytics.savedCardMethod }
        return type
    }

    private var effectiveCardID: String? {
        if usesNewCard { return nil }
        return selectedCardID ?? methods?.activeStored.first?.id
    }

    private func reference() -> MoonPayPaymentMethodReference? {
        guard let type = selectedMethodType, !isP2PSelected else { return nil }
        if type == Self.cardType, let id = effectiveCardID {
            let stored = methods?.stored.first { $0.id == id }
            return MoonPayPaymentMethodReference(type: stored?.type ?? type, id: id)
        }
        return MoonPayPaymentMethodReference(type: type)
    }

    /// MoonPay sends only the method type; the title, subtitle, icon and badge come from our backend.
    /// Without them the known types fall back to local names and the rest to a title derived from the type.
    private static func row(for config: MoonPayPaymentMethodConfig, info: MoonPayPaymentMethodInfo?) -> RampPaymentMethodRow {
        RampPaymentMethodRow(
            type: config.type,
            title: info?.title ?? fallbackTitle(for: config.type),
            image: info?.iconURL?.absoluteString ?? "",
            isP2P: false,
            subtitle: info?.subtitle,
            badge: info?.badge
        )
    }

    private static func fallbackTitle(for type: String) -> String {
        switch type {
        case applePayType: TKLocales.Ramp.Moonpay.PaymentMethod.applePay
        case cardType: TKLocales.Ramp.Moonpay.PaymentMethod.debitCard
        case "paypal": TKLocales.Ramp.Moonpay.PaymentMethod.paypal
        default: type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func resetQuoteState() {
        disclosures = []
        removeApplePayButton()
        quoteTask?.cancel()
        isRefreshingQuoteForContinue = false
        destinationAsset = nil
        quote = nil
        calculatedAmount = nil
        limitMessage = nil
        host?.applyRate(nil)
        host?.setConvertedShimmering(false)
    }

    /// MoonPay has no limits endpoint, but a quote for an amount below the minimum is rejected with it.
    private func suggestMinimumAmount() {
        minimumTask?.cancel()
        guard let host,
              let asset = host.asset,
              let destination = destinationAsset,
              let walletAddress = addressForAsset(asset),
              let reference = reference()
        else {
            host?.setLoadingMinimum(false)
            awaitsQuotability = false
            return
        }
        let fiat = host.fiatCode
        let assetId = asset.asset.assetId
        // Back from P2P, which dropped it, the hold comes back until the first probe answers.
        awaitsQuotability = mayBeUnquotable(destination, assetId: assetId)
        host.setLoadingMinimum(true)
        minimumTask = Task { [weak self] in
            guard let self else { return }
            var minimum: Decimal?
            var isUnquotable = false
            var isAnswered = true
            do {
                _ = try await service.buyQuote(
                    fiat: fiat,
                    amount: "0",
                    destination: destination,
                    walletAddress: walletAddress,
                    paymentMethod: reference
                )
            } catch {
                if case let .belowMinimum(value)? = (error as? MoonPayAPIError)?.buyAmountLimit {
                    minimum = value
                }
                isUnquotable = isUnquotableDeFi(error, destination: destination, assetId: assetId)
                // Only an amount limit shows MoonPay got to quoting; another error says nothing about it.
                if (error as? MoonPayAPIError)?.buyAmountLimit == nil {
                    isAnswered = false
                }
            }
            guard !Task.isCancelled else { return }
            if isAnswered, !isUnquotable {
                assetsProbed.insert(assetId)
            }
            host.setLoadingMinimum(false)
            // The first look already tells: the screen leaves MoonPay before an amount is typed.
            if isUnquotable, host.asset?.asset.assetId == assetId {
                handOverUnquotable(assetId)
                return
            }
            if awaitsQuotability {
                awaitsQuotability = false
            }
            guard let minimum, fiat == host.fiatCode, host.asset?.asset.assetId == assetId else { return }
            host.applyMinimumAmount(minimum)
        }
    }

    /// What one quote request is made of and for which state of the screen, to tell a stale answer.
    private struct QuoteRequest {
        let requested: BigUInt
        let amount: String
        let fiat: String
        let assetId: String
        let destination: MoonPayAsset
        let walletAddress: String
        let reference: MoonPayPaymentMethodReference
    }

    private func makeQuoteRequest() -> QuoteRequest? {
        guard let host,
              fiatAmount > 0,
              let asset = host.asset,
              let destination = destinationAsset,
              let walletAddress = addressForAsset(asset),
              let reference = reference()
        else { return nil }
        return QuoteRequest(
            requested: fiatAmount,
            amount: RampDataSourceDefaults.decimalString(fiatAmount, fractionDigits: host.fractionDigits),
            fiat: host.fiatCode,
            assetId: asset.asset.assetId,
            destination: destination,
            walletAddress: walletAddress,
            reference: reference
        )
    }

    private func fetchQuote(for request: QuoteRequest) async throws -> MoonPayBuyQuote {
        try await service.buyQuote(
            fiat: request.fiat,
            amount: request.amount,
            destination: request.destination,
            walletAddress: request.walletAddress,
            paymentMethod: request.reference
        )
    }

    /// A reconnect inside the request runs in its own task, and our backend reports its URL session
    /// being cancelled as `MultichainRampAPIError.cancelled` though this task is still live. That
    /// is transient, so it is retried once, as `MerchantRampSource` does for the widget URL.
    private func fetchQuoteRetryingCancellation(for request: QuoteRequest) async throws -> MoonPayBuyQuote {
        do {
            return try await fetchQuote(for: request)
        } catch MultichainRampAPIError.cancelled where !Task.isCancelled {
            return try await fetchQuote(for: request)
        }
    }

    private func isCurrent(_ request: QuoteRequest) -> Bool {
        request.requested == fiatAmount && host?.asset?.asset.assetId == request.assetId
    }

    private func apply(_ quote: MoonPayBuyQuote, for request: QuoteRequest) {
        self.quote = quote
        let newDisclosures = quote.paymentDisclosures ?? []
        if newDisclosures != disclosures {
            MoonPayPaymentDisclosures.reportUnknown(in: newDisclosures)
            disclosures = newDisclosures
        }
        calculatedAmount = request.requested
        host?.applyRate(Self.rate(of: quote), displayRate: Self.marketRate(of: quote))
        host?.restartRateTimer(lifetime: quote.lifetime)
        isApplePayButtonFailed = false
        updateApplePayButton(with: quote)
        redrawWhenQuoteGoesStale(quote)
    }

    /// The Apple Pay button checks the quote's lifetime when drawn, and nothing else redraws the
    /// screen as the lifetime runs out.
    private func redrawWhenQuoteGoesStale(_ quote: MoonPayBuyQuote) {
        quoteFreshnessTask?.cancel()
        guard let lifetime = quote.lifetime else { return }
        let delay = lifetime - Self.minimumRemainingLifetime
        guard delay > 0 else { return }
        quoteFreshnessTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.objectWillChange.send()
        }
    }

    // MARK: - Apple Pay button

    private func updateApplePayButton(with quote: MoonPayBuyQuote) {
        guard isApplePaySelected, quote.executable, !isApplePayButtonFailed else { return }
        if let applePayButton {
            applePayButton.setQuote(quote)
            return
        }
        guard applePayButtonTask == nil else { return }
        applePayButtonTask = Task { [weak self] in
            guard let self else { return }
            do {
                let button = try await service.applePayButton(
                    quote: quote,
                    height: RampInlineAction.height,
                    cornerRadius: RampInlineAction.cornerRadius
                )
                guard !Task.isCancelled, isApplePaySelected else {
                    button.discard()
                    return
                }
                applePayButtonTask = nil
                install(button)
            } catch {
                guard !Task.isCancelled else { return }
                applePayButtonTask = nil
                Log.multichainRamp.w("moonpay apple pay button failed", error: error)
                failApplePayButton(error)
            }
        }
    }

    private func install(_ button: MoonPayApplePayButton) {
        button.onReady = { [weak self] in
            self?.objectWillChange.send()
        }
        button.onPress = { [weak self, weak button] in
            guard let self, let button else { return }
            onApplePayPressed?(button.quote, payment.title, button.updates, button.externalTransactionId)
        }
        button.onFailToLoad = { [weak self] error in
            self?.failApplePayButton(error)
        }
        button.onFinish = { [weak self, weak button] in
            guard let self, let button, applePayButton === button else { return }
            applePayButton = nil
            // A button that ended before a tap failed in the frame (an `error` on load, say), and
            // a new one would fail the same way: wait for the next quote instead.
            guard button.isPressed else {
                isApplePayButtonFailed = true
                return
            }
            if let quote {
                updateApplePayButton(with: quote)
            }
        }
        applePayButton = button
        if let quote {
            button.setQuote(quote)
        }
    }

    private func failApplePayButton(_ error: Error) {
        isApplePayButtonFailed = true
        guard !didReportApplePayFailure else { return }
        didReportApplePayFailure = true
        // The button fails by itself, rebuilt on every amount change.
        host?.reportQuoteFailure(error)
    }

    /// A pressed button stays until its payment ends: its frame has to stay on screen to run.
    private func removeApplePayButton() {
        applePayButtonTask?.cancel()
        applePayButtonTask = nil
        isApplePayButtonFailed = false
        didReportApplePayFailure = false
        guard let applePayButton, !applePayButton.isPressed else { return }
        self.applePayButton = nil
        applePayButton.discard()
    }

    private func scheduleQuote(refreshing: Bool = false) {
        quoteTask?.cancel()
        isRefreshingQuoteForContinue = false
        if !refreshing {
            calculatedAmount = nil
            quote = nil
        }
        limitMessage = nil
        guard let host, let request = makeQuoteRequest() else {
            host?.applyRate(nil)
            host?.setConvertedShimmering(false)
            return
        }
        if !refreshing {
            host.setConvertedShimmering(true)
        }
        quoteTask = Task { [weak self] in
            if !refreshing {
                try? await Task.sleep(nanoseconds: RampDataSourceDefaults.quoteDebounce)
            }
            guard let self, !Task.isCancelled else { return }
            do {
                let quote = try await fetchQuoteRetryingCancellation(for: request)
                guard !Task.isCancelled, isCurrent(request) else { return }
                host.setConvertedShimmering(false)
                if let assetId = host.asset?.asset.assetId {
                    assetsQuoted.insert(assetId)
                    awaitsQuotability = false
                }
                apply(quote, for: request)
            } catch {
                guard !Task.isCancelled else { return }
                host.setConvertedShimmering(false)
                if isCurrent(request),
                   let destination = destinationAsset,
                   let assetId = host.asset?.asset.assetId,
                   isUnquotableDeFi(error, destination: destination, assetId: assetId)
                {
                    handOverUnquotable(assetId)
                    return
                }
                if let limit = (error as? MoonPayAPIError)?.buyAmountLimit {
                    guard request.requested == fiatAmount else { return }
                    quote = nil
                    calculatedAmount = nil
                    limitMessage = Self.message(for: limit, host: host)
                    host.applyRate(nil)
                    return
                }
                if refreshing {
                    host.restartRateTimer(lifetime: nil)
                } else if host.isOffline(error) {
                    // The amount received stays at the last rate, as the design shows offline;
                    // without a current quote Continue stays off.
                    host.restartRateTimer(lifetime: nil)
                } else {
                    // The previous quote was dropped for this request, so nothing is left for the
                    // rate line, the amount received or the quote timer to show.
                    host.applyRate(nil)
                }
                Log.multichainRamp.w("moonpay quote failed: \(error)")
                if refreshing {
                    host.reportQuoteFailure(error)
                } else {
                    host.reportFailure(error)
                }
            }
        }
    }

    /// The payment frame needs the quote for a few seconds after it opens, so a quote about to expire
    /// is replaced before paying with it.
    private static let minimumRemainingLifetime: TimeInterval = 3
    private static let serviceUnavailable = 503

    /// MoonPay lists DeFi tokens (AAVE, PEPE, WBTC) but answers their quotes with 503. Only a DeFi
    /// asset not quoted on this screen yet counts: a 503 for any other asset, or after a quote
    /// went through, is an outage, reported as such.
    private func isUnquotableDeFi(_ error: Error, destination: MoonPayAsset, assetId: String) -> Bool {
        guard mayBeUnquotable(destination, assetId: assetId),
              case .http(status: Self.serviceUnavailable, _)? = error as? MoonPayAPIError
        else { return false }
        return true
    }

    private func mayBeUnquotable(_ destination: MoonPayAsset?, assetId: String) -> Bool {
        guard let destination else { return false }
        return destination.caip19 != nil && !assetsQuoted.contains(assetId) && !assetsProbed.contains(assetId)
    }

    /// The merchants take the asset over, and end on the stub when our backend does not sell it either.
    private func handOverUnquotable(_ assetId: String) {
        Log.multichainRamp.w("moonpay quotes unavailable for \(assetId): merchants take over")
        assetsNotSold.insert(assetId)
        host?.fallBackToMerchant()
    }

    private func refreshQuoteAndContinue() {
        guard let host, let request = makeQuoteRequest() else { return }
        quoteTask?.cancel()
        isRefreshingQuoteForContinue = true
        quoteTask = Task { [weak self] in
            guard let self else { return }
            do {
                let fresh = try await fetchQuoteRetryingCancellation(for: request)
                guard !Task.isCancelled, isCurrent(request) else { return }
                isRefreshingQuoteForContinue = false
                apply(fresh, for: request)
                if fresh.executable {
                    onContinue?(fresh, payment.title)
                } else if let url = fresh.challengeURL {
                    onChallenge?(url)
                }
            } catch {
                guard !Task.isCancelled else { return }
                isRefreshingQuoteForContinue = false
                host.restartRateTimer(lifetime: nil)
                Log.multichainRamp.w("moonpay quote refresh before payment failed: \(error)")
                host.reportFailure(error)
            }
        }
    }

    private static func message(for limit: MoonPayBuyAmountLimit, host: RampDataSourceHost) -> String {
        switch limit {
        case let .belowMinimum(value):
            TKLocales.Ramp.Moonpay.Limit.minAmount(host.formatLimit(value))
        case let .aboveMaximum(value):
            TKLocales.Ramp.Moonpay.Limit.maxAmount(host.formatLimit(value))
        }
    }

    /// What one unit of fiat buys at MoonPay's market rate, without fees: `exchangeRate` is the
    /// fiat price of one unit of crypto. The rate shown on screen, hidden without it; `rate(of:)`
    /// keeps the fees in for the amount received.
    static func marketRate(of quote: MoonPayBuyQuote) -> Decimal? {
        guard let price = quote.exchangeRate.flatMap({ Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }),
              price > 0
        else { return nil }
        return 1 / price
    }

    private static func rate(of quote: MoonPayBuyQuote) -> Decimal? {
        let posix = Locale(identifier: "en_US_POSIX")
        guard let fiatValue = quote.source.amount.flatMap({ Decimal(string: $0, locale: posix) }),
              let cryptoValue = quote.destination.amount.flatMap({ Decimal(string: $0, locale: posix) }),
              fiatValue > 0,
              cryptoValue > 0
        else { return nil }
        return cryptoValue / fiatValue
    }
}
