import Foundation

public struct MoonPayAsset: Codable, Equatable, Sendable {
    /// CeFi asset code, e.g. `usd`, `ton`.
    public let code: String?
    /// CAIP-19 identifier for DeFi tokens.
    public let caip19: String?

    public init(code: String) {
        self.code = code
        caip19 = nil
    }

    public init(caip19: String) {
        code = nil
        self.caip19 = caip19
    }
}

public struct MoonPayMoney: Codable, Equatable, Sendable {
    /// Stringified decimal, as the API expects.
    public let amount: String?
    public let asset: MoonPayAsset

    public init(amount: String? = nil, asset: MoonPayAsset) {
        self.amount = amount
        self.asset = asset
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        amount = try container.decodeLenientStringIfPresent(forKey: .amount)
        asset = try container.decode(MoonPayAsset.self, forKey: .asset)
    }
}

public struct MoonPayWalletReference: Codable, Equatable, Sendable {
    public let address: String
    /// Memo / destination tag for chains that need one.
    public let tag: String?

    public init(address: String, tag: String? = nil) {
        self.address = address
        self.tag = tag
    }
}

public struct MoonPayPaymentMethodReference: Codable, Equatable, Sendable {
    /// `card`, `apple_pay`, `paypal`, …
    public let type: String?
    public let id: String?

    public init(type: String? = nil, id: String? = nil) {
        self.type = type
        self.id = id
    }
}

public enum MoonPayFeeBehavior: String, Codable, Sendable {
    /// Fees are deducted from the requested amount (API default).
    case inclusive
    /// Fees are added on top of the requested amount.
    case exclusive
}

/// Body of `POST /platform/v1/quotes/buy`. Exactly one of `source.amount` / `destination.amount`
/// is set.
public struct MoonPayBuyQuoteRequest: Encodable, Equatable, Sendable {
    public var source: MoonPayMoney
    public var destination: MoonPayMoney
    public var wallet: MoonPayWalletReference?
    public var paymentMethod: MoonPayPaymentMethodReference?
    public var feeBehavior: MoonPayFeeBehavior?

    public init(
        source: MoonPayMoney,
        destination: MoonPayMoney,
        wallet: MoonPayWalletReference? = nil,
        paymentMethod: MoonPayPaymentMethodReference? = nil,
        feeBehavior: MoonPayFeeBehavior? = nil
    ) {
        self.source = source
        self.destination = destination
        self.wallet = wallet
        self.paymentMethod = paymentMethod
        self.feeBehavior = feeBehavior
    }
}

public struct MoonPayBuyQuote: Decodable, Equatable, Sendable {
    public struct PaymentDisclosure: Decodable, Equatable, Sendable {
        public let id: String
        public let version: String?

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            version = try container.decodeLenientStringIfPresent(forKey: .version)
        }

        private enum CodingKeys: String, CodingKey {
            case id, version
        }
    }

    public let source: MoonPayMoney
    public let destination: MoonPayMoney
    /// Keyed by fee kind: `network`, `moonpay`, `ecosystem`, `defi`, `partner`.
    public let fees: [String: MoonPayMoney]?
    public let wallet: MoonPayWalletReference?
    public let paymentMethod: MoonPayPaymentMethodReference?
    public let feeBehavior: MoonPayFeeBehavior?
    public let expiresAt: Date?
    public let executable: Bool
    public let exchangeRate: String?
    public let exchangeRateType: String?
    /// Opaque token that a payment frame consumes as `signature` / `quoteSignature`.
    public let signature: String
    /// Present when the customer must pass a challenge before the quote becomes executable.
    public let challenge: MoonPayJSONValue?
    public let paymentDisclosures: [PaymentDisclosure]?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(MoonPayMoney.self, forKey: .source)
        destination = try container.decode(MoonPayMoney.self, forKey: .destination)
        fees = try? container.decodeIfPresent([String: MoonPayMoney].self, forKey: .fees)
        wallet = try container.decodeIfPresent(MoonPayWalletReference.self, forKey: .wallet)
        paymentMethod = try container.decodeIfPresent(MoonPayPaymentMethodReference.self, forKey: .paymentMethod)
        feeBehavior = try? container.decodeIfPresent(MoonPayFeeBehavior.self, forKey: .feeBehavior)
        expiresAt = try? container.decodeIfPresent(Date.self, forKey: .expiresAt)
        executable = try container.decodeIfPresent(Bool.self, forKey: .executable) ?? false
        exchangeRate = try container.decodeLenientStringIfPresent(forKey: .exchangeRate)
        exchangeRateType = try container.decodeIfPresent(String.self, forKey: .exchangeRateType)
        signature = try container.decode(String.self, forKey: .signature)
        challenge = try container.decodeIfPresent(MoonPayJSONValue.self, forKey: .challenge)
        paymentDisclosures = try? container.decodeIfPresent([PaymentDisclosure].self, forKey: .paymentDisclosures)
    }

    public var challengeURL: URL? {
        challenge?["url"]?.stringValue.flatMap(URL.init(string:))
    }

    private enum CodingKeys: String, CodingKey {
        case source, destination, fees, wallet, paymentMethod, feeBehavior, expiresAt, executable
        case exchangeRate, exchangeRateType, signature, challenge, paymentDisclosures
    }
}

struct MoonPayBuyQuoteResponse: Decodable {
    let data: MoonPayBuyQuote
}
