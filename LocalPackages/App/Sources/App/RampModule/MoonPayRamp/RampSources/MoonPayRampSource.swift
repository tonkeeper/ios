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

@MainActor
final class MoonPayRampSource: ObservableObject, RampDataSource {
    var onSelectPaymentMethod: (([RampPaymentMethodRow], String?, [MoonPaySavedCard], String?) -> Void)?
    var onAddCard: (() -> Void)?
    var onChallenge: ((URL) -> Void)?
    var onContinue: ((MoonPayBuyQuote, String) -> Void)?

    weak var host: RampDataSourceHost?

    @Published private var paymentRows: [RampPaymentMethodRow] = []
    @Published private var selectedMethodType: String?
    @Published private var calculatedAmount: BigUInt?
    @Published private var limitMessage: String?
    @Published private(set) var isLoadingMethods = false

    private let service: MoonPayRampService
    private let addressForAsset: (MultichainAsset) -> String?
    private var methods: MoonPayPaymentMethods?
    private var quote: MoonPayBuyQuote?
    private var destinationAsset: MoonPayAsset?
    private var selectedCardID: String?
    private var usesNewCard = false
    private var methodsTask: Task<Void, Never>?
    private var quoteTask: Task<Void, Never>?
    private var minimumTask: Task<Void, Never>?

    init(service: MoonPayRampService, addressForAsset: @escaping (MultichainAsset) -> String?) {
        self.service = service
        self.addressForAsset = addressForAsset
    }

    deinit {
        methodsTask?.cancel()
        quoteTask?.cancel()
        minimumTask?.cancel()
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
                savedCard: MoonPaySavedCardIcon(brand: presentation.brand, last4: presentation.last4)
            )
        }
        return .init(title: row.title, subtitle: row.subtitle, iconURL: row.imageURL)
    }

    var isConfigured: Bool {
        service.isConfigured
    }

    var isConnected: Bool {
        service.isConnected
    }

    func connect() async -> Bool {
        do {
            _ = try await service.ensureConnected()
            return true
        } catch {
            Log.multichainRamp.w("moonpay authorization failed, using merchants", error: error)
            return false
        }
    }

    var limitText: String? {
        nil
    }

    var hasNoPaymentMethods: Bool {
        methods != nil && paymentRows.isEmpty
    }

    var actionTitle: String? {
        limitMessage
    }

    var isActionEnabled: Bool {
        guard host?.asset != nil else { return false }
        guard limitMessage == nil else { return false }
        if isCardSelected, effectiveCardID == nil { return true }
        return quote != nil && fiatAmount > 0 && fiatAmount == calculatedAmount
    }

    var isActionLoading: Bool {
        false
    }

    var canRefreshQuote: Bool {
        quote != nil && fiatAmount > 0
    }

    func reloadMethods() {
        methodsTask?.cancel()
        minimumTask?.cancel()
        resetQuoteState()
        isLoadingMethods = false
        guard let host else { return }
        host.setLoadingMinimum(false)
        let fiat = host.fiatCode
        let assetDetails = host.asset?.asset
        isLoadingMethods = true
        methodsTask = Task { [weak self] in
            guard let self else { return }
            do {
                async let loadedMethods = service.paymentMethods(fiat: fiat)
                async let loadedDestination = resolveDestination(of: assetDetails)
                let methods = try await loadedMethods
                let destination = try await loadedDestination
                guard !Task.isCancelled else { return }
                if let assetDetails, destination == nil, host.asset?.asset.assetId == assetDetails.assetId {
                    isLoadingMethods = false
                    host.fallBackToMerchant()
                    return
                }
                guard !Task.isCancelled, fiat == host.fiatCode, host.asset?.asset.assetId == assetDetails?.assetId else { return }
                isLoadingMethods = false
                destinationAsset = destination
                self.methods = methods
                let rows = methods.activeConfigs.filter(\.supportsBuy).map(Self.row)
                paymentRows = rows
                if rows.isEmpty {
                    host.didFindNoPaymentMethods()
                    return
                }
                let current = selectedMethodType
                if !rows.contains(where: { $0.type == current }) {
                    selectedMethodType = rows.first?.type
                }
                suggestMinimumAmount()
                scheduleQuote()
            } catch {
                guard !Task.isCancelled else { return }
                isLoadingMethods = false
                host.fallBackToMerchant()
            }
        }
    }

    private func resolveDestination(of details: MultichainAssetDetails?) async throws -> MoonPayAsset? {
        guard let details else { return nil }
        return try await service.destinationAsset(for: details)
    }

    func selectMethod(_ type: String) {
        selectedMethodType = type
        if type == Self.cardType {
            usesNewCard = true
            selectedCardID = nil
        }
        suggestMinimumAmount()
        scheduleQuote()
    }

    func selectSavedCard(_ id: String) {
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

    func amountDidChange() {
        scheduleQuote()
    }

    func refreshQuote() {
        scheduleQuote(refreshing: true)
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
        onContinue?(quote, payment.title)
    }

    func deactivate() {
        isLoadingMethods = false
        minimumTask?.cancel()
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

    private var fiatAmount: BigUInt {
        host?.fiatAmount ?? 0
    }

    private var isCardSelected: Bool {
        selectedMethodType == Self.cardType
    }

    private var effectiveCardID: String? {
        if usesNewCard { return nil }
        return selectedCardID ?? methods?.activeStored.first?.id
    }

    private func reference() -> MoonPayPaymentMethodReference? {
        guard let type = selectedMethodType else { return nil }
        if type == Self.cardType, let id = effectiveCardID {
            let stored = methods?.stored.first { $0.id == id }
            return MoonPayPaymentMethodReference(type: stored?.type ?? type, id: id)
        }
        return MoonPayPaymentMethodReference(type: type)
    }

    /// MoonPay sends only the method type, so names and icons for the known ones are local; any other
    /// type is shown with a title derived from the type until the data source for it is decided.
    private static func row(for config: MoonPayPaymentMethodConfig) -> RampPaymentMethodRow {
        switch config.type {
        case "apple_pay":
            RampPaymentMethodRow(type: config.type, title: TKLocales.Ramp.Moonpay.PaymentMethod.applePay, image: "", isP2P: false)
        case cardType:
            RampPaymentMethodRow(type: config.type, title: TKLocales.Ramp.Moonpay.PaymentMethod.debitCard, image: "", isP2P: false)
        case "paypal":
            RampPaymentMethodRow(type: config.type, title: TKLocales.Ramp.Moonpay.PaymentMethod.paypal, image: "", isP2P: false)
        default:
            RampPaymentMethodRow(
                type: config.type,
                title: config.type.replacingOccurrences(of: "_", with: " ").capitalized,
                image: "",
                isP2P: false
            )
        }
    }

    private func resetQuoteState() {
        quoteTask?.cancel()
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
            return
        }
        let fiat = host.fiatCode
        let assetId = asset.asset.assetId
        host.setLoadingMinimum(true)
        minimumTask = Task { [weak self] in
            guard let self else { return }
            var minimum: Decimal?
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
            }
            guard !Task.isCancelled else { return }
            host.setLoadingMinimum(false)
            guard let minimum, fiat == host.fiatCode, host.asset?.asset.assetId == assetId else { return }
            host.applyMinimumAmount(minimum)
        }
    }

    private func scheduleQuote(refreshing: Bool = false) {
        quoteTask?.cancel()
        if !refreshing {
            calculatedAmount = nil
            quote = nil
        }
        limitMessage = nil
        guard let host,
              fiatAmount > 0,
              let asset = host.asset,
              let destination = destinationAsset,
              let walletAddress = addressForAsset(asset),
              let reference = reference()
        else {
            host?.applyRate(nil)
            host?.setConvertedShimmering(false)
            return
        }
        let requested = fiatAmount
        let amount = RampDataSourceDefaults.decimalString(requested, fractionDigits: host.fractionDigits)
        let fiat = host.fiatCode
        let assetId = asset.asset.assetId
        if !refreshing {
            host.setConvertedShimmering(true)
        }
        quoteTask = Task { [weak self] in
            if !refreshing {
                try? await Task.sleep(nanoseconds: RampDataSourceDefaults.quoteDebounce)
            }
            guard let self, !Task.isCancelled else { return }
            do {
                let quote = try await service.buyQuote(
                    fiat: fiat,
                    amount: amount,
                    destination: destination,
                    walletAddress: walletAddress,
                    paymentMethod: reference
                )
                guard !Task.isCancelled, requested == fiatAmount, host.asset?.asset.assetId == assetId else { return }
                self.quote = quote
                calculatedAmount = requested
                host.setConvertedShimmering(false)
                host.applyRate(Self.rate(of: quote))
                host.restartRateTimer()
            } catch {
                guard !Task.isCancelled else { return }
                host.setConvertedShimmering(false)
                if let limit = (error as? MoonPayAPIError)?.buyAmountLimit {
                    guard requested == fiatAmount else { return }
                    quote = nil
                    calculatedAmount = nil
                    limitMessage = Self.message(for: limit, host: host)
                    host.applyRate(nil)
                    return
                }
                if refreshing {
                    host.restartRateTimer()
                }
                Log.multichainRamp.w("moonpay quote failed: \(error)")
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
