import AppUI
import BigInt
import Combine
import Foundation
import KeeperCore
import MoonPay
import TKUIKit
import UIKit

@MainActor
protocol RampDataSourceHost: AnyObject {
    var asset: MultichainAsset? { get }
    var fiatCode: String { get }
    var fiatAmount: BigUInt { get }
    var fractionDigits: Int { get }
    /// MoonPay is the provider but waits for the sign-in: the merchants list MoonPay's widget's
    /// methods only, as the native MoonPay's are not known yet.
    var listsMoonPayWidgetMethods: Bool { get }

    func applyMinimumAmount(_ value: Decimal)
    /// While the minimum is being looked up, the quick options shimmer instead of showing stale amounts.
    func setLoadingMinimum(_ isOn: Bool)
    /// `rate` converts the entered amount into what the user receives, fees included.
    /// `displayRate` is the one written on screen, such as MoonPay's market rate without fees;
    /// without it the screen shows no rate.
    func applyRate(_ rate: Decimal?, displayRate: Decimal?)
    func formatLimit(_ value: Decimal) -> String
    func setConvertedShimmering(_ isOn: Bool)
    /// `lifetime` is how long the new quote is valid; without it the default rate timer applies.
    func restartRateTimer(lifetime: TimeInterval?)
    func reportFailure(_ error: Error)
    /// A failure nobody asked for, such as the rate timer's quote refresh or the Apple Pay button:
    /// "No internet connection" for it is not repeated on every attempt, unlike for an action the
    /// user took.
    func reportQuoteFailure(_ error: Error)
    /// The request failed for the lack of network.
    func isOffline(_ error: Error) -> Bool
    func fallBackToMerchant()
    /// The merchant the user picked does not sell the asset in the currency any more. Returns true
    /// when the host took another source for it, such as MoonPay; the merchants then stop loading.
    func merchantPickDidDrop() -> Bool
    /// Our backend does not sell the asset (404). Returns true when a connected MoonPay that may
    /// sell it took the screen, once per asset and currency.
    func merchantsDoNotSell() -> Bool
}

extension RampDataSourceHost {
    func applyRate(_ rate: Decimal?) {
        applyRate(rate, displayRate: rate)
    }
}

/// Who the ramp screen's Continue goes to.
enum RampProvider: Equatable {
    case moonPay
    /// The merchant the user picked, or without one the merchant with the best rate.
    case merchant(id: String?)
}

/// Where the ramp screen takes payment methods and quotes from, and what Continue does.
@MainActor
protocol RampDataSource: AnyObject {
    var objectWillChange: ObservableObjectPublisher { get }
    var host: RampDataSourceHost? { get set }

    var payment: MoonPayRampViewState.Payment { get }
    /// Replaces the Continue title while the button is disabled for a reason the user can fix.
    var actionTitle: String? { get }
    var isLoadingMethods: Bool { get }
    /// The payment methods were loaded for the current asset and currency, and there are none.
    var hasNoPaymentMethods: Bool { get }
    /// The selected method as the deposit funnel names it; nil without one and for P2P.
    var analyticsMethod: String? { get }
    var isActionEnabled: Bool { get }
    var isActionLoading: Bool { get }
    var canRefreshQuote: Bool { get }

    func reloadMethods()
    func selectMethod(_ type: String)
    func amountDidChange()
    func refreshQuote()
    func tapPaymentMethod()
    func tapAction()
    func deactivate()
    /// Takes the place of the Continue button while it is set.
    var inlineAction: RampInlineAction? { get }
    /// The legal texts the provider's quote asks to show before the payment.
    var paymentDisclosures: [MoonPayBuyQuote.PaymentDisclosure] { get }
    /// The quote of the amount on screen whose price details the screen offers.
    var priceQuote: MoonPayBuyQuote? { get }
}

/// A frame shown instead of the Continue button, such as the Apple Pay button, which only works
/// when the user taps it inside the frame.
struct RampInlineAction {
    /// `nil` while the frame is being created.
    let controller: UIViewController?
    /// The frame rendered its content; until then the screen shows a placeholder in its place.
    let isReady: Bool
    let isEnabled: Bool

    /// The Apple Pay button is 2 pt shorter than Continue in the design.
    static let height: CGFloat = 54
    /// As a large action button: a capsule under liquid glass.
    @MainActor static var cornerRadius: CGFloat {
        TKLiquidGlass.isEnabled ? height / 2 : 16
    }
}

extension RampDataSource {
    var inlineAction: RampInlineAction? {
        nil
    }

    var paymentDisclosures: [MoonPayBuyQuote.PaymentDisclosure] {
        []
    }

    var priceQuote: MoonPayBuyQuote? {
        nil
    }
}

extension RampDataSourceHost {
    func restartRateTimer() {
        restartRateTimer(lifetime: nil)
    }
}

enum RampDataSourceDefaults {
    static let quoteDebounce: UInt64 = 400_000_000

    static func minorUnits(_ value: Decimal, fractionDigits: Int) -> BigUInt {
        guard value > 0 else { return 0 }
        var scaled = value * Decimal(sign: .plus, exponent: fractionDigits, significand: 1)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .up)
        return BigUInt(NSDecimalNumber(decimal: rounded).stringValue) ?? 0
    }

    static func decimalString(_ amount: BigUInt, fractionDigits: Int) -> String {
        let raw = String(amount)
        guard fractionDigits > 0 else { return raw }
        let padded = String(repeating: "0", count: max(0, fractionDigits + 1 - raw.count)) + raw
        let split = padded.index(padded.endIndex, offsetBy: -fractionDigits)
        var fraction = String(padded[split...])
        while fraction.hasSuffix("0") {
            fraction.removeLast()
        }
        let integer = String(padded[..<split])
        return fraction.isEmpty ? integer : "\(integer).\(fraction)"
    }
}
