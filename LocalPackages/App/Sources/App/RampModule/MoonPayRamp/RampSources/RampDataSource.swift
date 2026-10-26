import AppUI
import BigInt
import Combine
import Foundation
import KeeperCore

@MainActor
protocol RampDataSourceHost: AnyObject {
    var asset: MultichainAsset? { get }
    var fiatCode: String { get }
    var fiatAmount: BigUInt { get }
    var fractionDigits: Int { get }

    func applyMinimumAmount(_ value: Decimal)
    /// While the minimum is being looked up, the quick options shimmer instead of showing stale amounts.
    func setLoadingMinimum(_ isOn: Bool)
    /// The methods for the current asset and currency came back empty.
    func didFindNoPaymentMethods()
    func applyRate(_ rate: Decimal?)
    func formatLimit(_ value: Decimal) -> String
    func setConvertedShimmering(_ isOn: Bool)
    func restartRateTimer()
    func reportFailure(_ error: Error)
    func fallBackToMerchant()
}

/// Where the ramp screen takes payment methods and quotes from, and what Continue does.
@MainActor
protocol RampDataSource: AnyObject {
    var objectWillChange: ObservableObjectPublisher { get }
    var host: RampDataSourceHost? { get set }

    var payment: MoonPayRampViewState.Payment { get }
    var limitText: String? { get }
    /// Replaces the Continue title while the button is disabled for a reason the user can fix.
    var actionTitle: String? { get }
    var isLoadingMethods: Bool { get }
    /// The payment methods were loaded for the current asset and currency, and there are none.
    var hasNoPaymentMethods: Bool { get }
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
