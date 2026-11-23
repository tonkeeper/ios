import Foundation
import KeeperCore
import TKCore

/// What a step of a purchase on Buy crypto was for.
struct BuyCryptoPurchase: Equatable {
    let assetId: String
    let fiat: String
    /// The backend's slug of a merchant's method; for MoonPay `card` for a new card, `saved_card`
    /// for a card MoonPay keeps, otherwise MoonPay's method type.
    let paymentMethod: String
    /// The merchant's title, or `MoonPay`.
    let provider: String
    /// `headless` for MoonPay's checkout in the app, `merchant` for a page that opens outside it,
    /// MoonPay's widget included: `provider` is `MoonPay` for both.
    let mode: RampProviderMode

    /// The same purchase in the mode of the path Continue took, which can differ from the mode
    /// of its provider: a method MoonPay's widget does not take skips the sign-in for a merchant.
    func with(mode: RampProviderMode) -> BuyCryptoPurchase {
        BuyCryptoPurchase(assetId: assetId, fiat: fiat, paymentMethod: paymentMethod, provider: provider, mode: mode)
    }
}

/// Buy crypto reports through the deposit funnel with the events of the Add Funds screens it
/// replaces, so both compare in one funnel; `deposit_screen = buy_crypto` tells them apart.
/// Every event is for buying with fiat, the only option the screen has.
@MainActor
final class BuyCryptoAnalytics {
    static let moonPayProvider = "MoonPay"
    static let savedCardMethod = "saved_card"

    let source: RampSource
    let utm: UtmParameters
    private let send: (Encodable, UtmParameters) -> Void
    private var isAmountShown = false

    init(source: RampSource, utm: UtmParameters, send: @escaping (Encodable, UtmParameters) -> Void) {
        self.source = source
        self.utm = utm
        self.send = send
    }

    /// Once per opening of the screen, from every entry, those with an asset included.
    func started() {
        send(DepositStarted(
            from: source,
            walletMode: .multi,
            depositScreen: .buyCrypto,
            availableOptions: [AddFundsOption.buyWithFiat.rawValue]
        ))
    }

    func assetListShown(_ assetIds: [String]) {
        send(DepositViewFiatChooseAsset(
            from: source,
            addFundsOption: .buyWithFiat,
            depositScreen: .buyCrypto,
            availableOptions: Set(assetIds)
        ))
    }

    func assetPicked(_ assetId: String) {
        send(DepositClickFiatAsset(from: source, addFundsOption: .buyWithFiat, depositScreen: .buyCrypto, buyAsset: assetId))
    }

    func methodsShown(assetId: String, fiat: String, methods: [String]) {
        send(DepositViewFiatPaymentMethod(
            from: source,
            addFundsOption: .buyWithFiat,
            depositScreen: .buyCrypto,
            buyAsset: assetId,
            sellAsset: fiat,
            availableOptions: Set(methods)
        ))
    }

    func methodPicked(assetId: String, fiat: String, method: String) {
        send(DepositClickFiatPaymentMethod(
            from: source,
            addFundsOption: .buyWithFiat,
            depositScreen: .buyCrypto,
            buyAsset: assetId,
            sellAsset: fiat,
            paymentMethod: method
        ))
    }

    /// Once per opening, as soon as the provider is known.
    func amountShown(_ purchase: BuyCryptoPurchase) {
        guard !isAmountShown else { return }
        isAmountShown = true
        send(DepositViewRampInsertAmount(
            from: source,
            addFundsOption: .buyWithFiat,
            depositScreen: .buyCrypto,
            buyAsset: purchase.assetId,
            sellAsset: purchase.fiat,
            paymentMethod: purchase.paymentMethod,
            providerName: purchase.provider,
            providerMode: purchase.mode
        ))
    }

    func continued(_ purchase: BuyCryptoPurchase) {
        send(DepositClickRampInsertAmountContinue(
            from: source,
            addFundsOption: .buyWithFiat,
            depositScreen: .buyCrypto,
            buyAsset: purchase.assetId,
            sellAsset: purchase.fiat,
            paymentMethod: purchase.paymentMethod,
            providerName: purchase.provider,
            providerMode: purchase.mode
        ))
    }

    /// The merchant's page opens, or MoonPay's payment starts. `txId` is ours for this attempt:
    /// every Continue is a new one.
    func toProvider(_ purchase: BuyCryptoPurchase, txId: String) {
        send(DepositContinueToRampProvider(
            from: source,
            walletMode: .multi,
            addFundsOption: .buyWithFiat,
            depositScreen: .buyCrypto,
            buyAsset: purchase.assetId,
            sellAsset: purchase.fiat,
            paymentMethod: purchase.paymentMethod,
            providerName: purchase.provider,
            providerMode: purchase.mode,
            txId: txId
        ))
    }

    func toP2P() {
        send(DepositContinueToP2pMarket(from: source, walletMode: .multi, addFundsOption: .buyWithFiat, depositScreen: .buyCrypto))
    }

    func receiveShown(token: Token) {
        send(source.makeDepositViewReceiveTokens(token: token, walletMode: .multi, depositScreen: .buyCrypto))
    }

    /// How MoonPay's payment ended, once per attempt.
    func result(
        _ purchase: BuyCryptoPurchase,
        txId: String,
        outcome: DepositRampResult.Outcome,
        failureReason: DepositRampResult.FailureReason?
    ) {
        send(DepositRampResult(
            from: source,
            walletMode: .multi,
            addFundsOption: .buyWithFiat,
            depositScreen: .buyCrypto,
            buyAsset: purchase.assetId,
            sellAsset: purchase.fiat,
            paymentMethod: purchase.paymentMethod,
            providerName: purchase.provider,
            providerMode: purchase.mode,
            txId: txId,
            outcome: outcome,
            failureReason: outcome == .failed ? failureReason ?? .unknown : nil
        ))
    }

    private func send(_ event: Encodable) {
        send(event, utm)
    }
}
