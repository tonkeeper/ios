import Foundation

public struct Rates: Codable, Equatable {
    public struct Rate: Equatable {
        public let currency: Currency
        public let rate: Decimal
        public let diff24h: String?

        public init(currency: Currency, rate: Decimal, diff24h: String?) {
            self.currency = currency
            self.rate = rate
            self.diff24h = diff24h
        }
    }

    public var ton: [Rate]
    public var usdt: [Rate]
    public var jettonRates: [String: [Rate]]
}

/// Written by hand because the generated `TonAPI` module extends `KeyedEncodingContainerProtocol`
/// with a `Decimal` overload that formats through a `NumberFormatter` — three fraction digits, so a
/// synthesized conformance would store every rate below 0.0005 as zero.
extension Rates.Rate: Codable {
    private enum CodingKeys: String, CodingKey {
        case currency
        case rate
        case diff24h
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currency = try container.decode(Currency.self, forKey: .currency)
        diff24h = try container.decodeIfPresent(String.self, forKey: .diff24h)
        if let string = try? container.decode(String.self, forKey: .rate) {
            guard let rate = Decimal(string: string) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .rate,
                    in: container,
                    debugDescription: "Rate is not a number: \(string)"
                )
            }
            self.rate = rate
        } else {
            let value = try container.decode(Double.self, forKey: .rate)
            guard let rate = Decimal(
                string: String(value),
                locale: Locale(identifier: "en_US_POSIX")
            ) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .rate,
                    in: container,
                    debugDescription: "Rate is not a number: \(value)"
                )
            }
            self.rate = rate
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currency, forKey: .currency)
        try container.encode(rate.description, forKey: .rate)
        try container.encodeIfPresent(diff24h, forKey: .diff24h)
    }
}
