import Foundation
import MoonPay
import TKLogging

/// The legal texts MoonPay's quote names in `paymentDisclosures`, as MoonPay's go-live guide
/// gives them. MoonPay sends only their ids and versions; the copy must be shown verbatim, in
/// English, so it is kept here rather than in the translated strings.
enum MoonPayPaymentDisclosures {
    /// The copy here is of these versions; a newer one means MoonPay has changed the wording.
    static let knownVersion = "1"

    static func texts(for disclosures: [MoonPayBuyQuote.PaymentDisclosure]) -> [AttributedString] {
        var shown: [Disclosure] = []
        for disclosure in disclosures {
            // MoonPay asks for a conservative disclosure in place of one it has not told us about.
            let text = Disclosure(rawValue: disclosure.id) ?? .transactionFinality
            if !shown.contains(text) {
                shown.append(text)
            }
        }
        return shown.map(\.attributedText)
    }

    /// Logs, as an error so release builds report it, each disclosure whose copy is not here or is
    /// of an older wording. Called once per new set of disclosures, not per redraw.
    static func reportUnknown(in disclosures: [MoonPayBuyQuote.PaymentDisclosure]) {
        for disclosure in disclosures
            where Disclosure(rawValue: disclosure.id) == nil || disclosure.version.map({ $0 != knownVersion }) == true
        {
            Log.multichainRamp.e("unknown moonpay disclosure '\(disclosure.id)' v\(disclosure.version ?? "-")")
        }
    }

    enum Disclosure: String {
        case transactionFinality = "us-transaction-finality"
        case cryptoAssetRisk = "eea-crypto-asset-risk"
        case unregulatedStablecoinRisk = "eea-unregulated-stablecoin-risk"
        case gatewayToken = "gateway-token"

        var markdown: String {
            switch self {
            case .transactionFinality:
                "I agree to MoonPay’s [Terms of Use](\(Link.terms)) and understand that, once executed, this transaction cannot be cancelled, recalled, refunded, or otherwise undone. Fraudulent transactions may result in the loss of funds with no recourse."
            case .cryptoAssetRisk:
                "By continuing, you agree to transact with MoonPay Europe, subject to its [Terms of Use](\(Link.terms)) and [Privacy Policy](\(Link.privacyPolicy)). Crypto-assets can be risky and values may decrease quickly. Transfers are irreversible once broadcast to the blockchain. The quoted exchange rate may include a spread. [Learn more](\(Link.legal)) and [review the whitepaper](\(Link.whitepapers)) (if available)."
            case .unregulatedStablecoinRisk:
                "Important: You are about to transact in a stablecoin that is not MiCA-compliant, carries fewer safeguards, and may be difficult to sell. By continuing, you agree to transact with MoonPay Europe subject to its [Terms of Use](\(Link.terms)) and [Privacy Policy](\(Link.privacyPolicy)). Transfers are irreversible once broadcast to the blockchain. The quoted exchange rate may include a spread. [Learn more](\(Link.legal)) and [review the whitepaper](\(Link.whitepapers)) (if available)."
            case .gatewayToken:
                "By proceeding, you agree to two steps under [these terms](\(Link.terms)): (1) Buying stablecoin from MoonPay and (2) Swapping stablecoin for your chosen destination asset via a decentralised exchange."
            }
        }

        var attributedText: AttributedString {
            (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
        }
    }

    private enum Link {
        static let terms = "https://www.moonpay.com/legal/terms"
        static let privacyPolicy = "https://www.moonpay.com/legal/privacy_policy"
        static let legal = "https://www.moonpay.com/legal"
        static let whitepapers = "https://dev.moonpay.com/docs/list-of-supported-cryptocurrencies"
    }
}
