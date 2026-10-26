import Foundation

/// Availability of a payment-method configuration or of a stored payment method.
public struct MoonPayPaymentMethodAvailability: Codable, Equatable, Sendable {
    public let active: Bool
    /// `card_expired`, `card_declined`, `card_blocked`, …
    public let reasons: [String]

    public init(active: Bool, reasons: [String] = []) {
        self.active = active
        self.reasons = reasons
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? false
        reasons = try container.decodeIfPresent([String].self, forKey: .reasons) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case active, reasons
    }
}

/// One entry of `paymentMethodConfigs`: a payment method type the connected customer may use.
public struct MoonPayPaymentMethodConfig: Decodable, Equatable, Sendable {
    public struct Capabilities: Decodable, Equatable, Sendable {
        public let supportedCurrencies: [String]
        public let supportedTransactionTypes: [String]
        public let allowsDeletion: Bool
        public let requiresWidget: Bool

        public init(
            supportedCurrencies: [String] = [],
            supportedTransactionTypes: [String] = [],
            allowsDeletion: Bool = false,
            requiresWidget: Bool = false
        ) {
            self.supportedCurrencies = supportedCurrencies
            self.supportedTransactionTypes = supportedTransactionTypes
            self.allowsDeletion = allowsDeletion
            self.requiresWidget = requiresWidget
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            supportedCurrencies = try container.decodeIfPresent([String].self, forKey: .supportedCurrencies) ?? []
            supportedTransactionTypes = try container.decodeIfPresent([String].self, forKey: .supportedTransactionTypes) ?? []
            allowsDeletion = try container.decodeIfPresent(Bool.self, forKey: .allowsDeletion) ?? false
            requiresWidget = try container.decodeIfPresent(Bool.self, forKey: .requiresWidget) ?? false
        }

        public var supportsBuy: Bool {
            supportedTransactionTypes.contains("buy")
        }

        private enum CodingKeys: String, CodingKey {
            case supportedCurrencies, supportedTransactionTypes, allowsDeletion, requiresWidget
        }
    }

    /// `card`, `apple_pay`, `sepa`, `paypal`, … kept raw so a type added later still renders.
    public let type: String
    public let capabilities: Capabilities?
    public let availability: MoonPayPaymentMethodAvailability?

    public init(type: String, capabilities: Capabilities? = nil, availability: MoonPayPaymentMethodAvailability? = nil) {
        self.type = type
        self.capabilities = capabilities
        self.availability = availability
    }

    public var isActive: Bool {
        availability?.active ?? false
    }

    /// Unknown capabilities are not treated as a restriction.
    public var supportsBuy: Bool {
        capabilities?.supportsBuy ?? true
    }
}

/// `GET /platform/v1/payment-methods`: the types available to the connected customer and the
/// payment methods already stored on the account.
public struct MoonPayPaymentMethods: Decodable, Equatable, Sendable {
    public let configs: [MoonPayPaymentMethodConfig]
    public let stored: [MoonPaySavedCard]

    public init(configs: [MoonPayPaymentMethodConfig], stored: [MoonPaySavedCard]) {
        self.configs = configs
        self.stored = stored
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        configs = try container.decodeIfPresent([MoonPayPaymentMethodConfig].self, forKey: .configs) ?? []
        // MoonPay lists wallets such as Apple Pay and Google Pay here with placeholder ids; only
        // cards carry a payment method id that a quote and the buy frame accept.
        stored = try (container.decodeIfPresent([MoonPaySavedCard].self, forKey: .stored) ?? [])
            .filter { $0.type == nil || $0.type == "card" }
    }

    public var activeConfigs: [MoonPayPaymentMethodConfig] {
        configs.filter(\.isActive)
    }

    public var activeStored: [MoonPaySavedCard] {
        stored.filter { $0.availability?.active ?? false }
    }

    private enum CodingKeys: String, CodingKey {
        case configs = "paymentMethodConfigs"
        case stored = "paymentMethods"
    }
}

struct MoonPayPaymentMethodsResponse: Decodable {
    let data: MoonPayPaymentMethods
}
