import Foundation

public struct MoonPayTransaction: Codable, Equatable, Sendable {
    public let id: String?
    public let status: String
    public let failureCode: String?
    public let failureReason: String?

    public init(id: String?, status: String, failureCode: String? = nil, failureReason: String? = nil) {
        self.id = id
        self.status = status
        self.failureCode = failureCode
        self.failureReason = failureReason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeLenientStringIfPresent(forKey: .id)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        failureCode = try container.decodeIfPresent(String.self, forKey: .failureCode)
        failureReason = try container.decodeIfPresent(String.self, forKey: .failureReason)
    }

    public var isFailed: Bool {
        status == MoonPayTransactionStatus.failed
    }

    public var isCompleted: Bool {
        status == MoonPayTransactionStatus.completed
    }
}

enum MoonPayTransactionStatus {
    static let completed = "completed"
    static let failed = "failed"
}

/// `GET /platform/v1/transactions/{id}`: the transaction as MoonPay currently sees it.
public struct MoonPayTransactionDetails: Decodable, Equatable, Sendable {
    public struct Stage: Decodable, Equatable, Sendable {
        public let kind: String?
        public let name: String?
        public let status: String?
        public let failureReason: String?

        public init(kind: String? = nil, name: String? = nil, status: String? = nil, failureReason: String? = nil) {
            self.kind = kind
            self.name = name
            self.status = status
            self.failureReason = failureReason
        }
    }

    public let id: String
    public let status: String
    public let transactionHash: String?
    public let customerID: String?
    public let stages: [Stage]

    public init(
        id: String,
        status: String,
        transactionHash: String? = nil,
        customerID: String? = nil,
        stages: [Stage] = []
    ) {
        self.id = id
        self.status = status
        self.transactionHash = transactionHash
        self.customerID = customerID
        self.stages = stages
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        transactionHash = try container.decodeIfPresent(String.self, forKey: .transactionHash)
        customerID = try container.decodeIfPresent(Customer.self, forKey: .customer)?.id
        stages = try container.decodeIfPresent([Stage].self, forKey: .stages) ?? []
    }

    public var isFailed: Bool {
        status == MoonPayTransactionStatus.failed
    }

    public var isCompleted: Bool {
        status == MoonPayTransactionStatus.completed
    }

    public var failedStage: Stage? {
        stages.first { $0.status == "failed" }
    }

    private struct Customer: Decodable {
        let id: String
    }

    private enum CodingKeys: String, CodingKey {
        case id, status, transactionHash, customer, stages
    }
}

struct MoonPayTransactionResponse: Decodable {
    let data: MoonPayTransactionDetails
}

/// A stored payment method: the `complete` payload of the `add-card` frame and each entry of
/// `paymentMethods` in `GET /platform/v1/payment-methods`.
public struct MoonPaySavedCard: Codable, Equatable, Identifiable, Sendable {
    public typealias Availability = MoonPayPaymentMethodAvailability

    public let id: String
    public let type: String?
    public let cardType: String?
    public let brand: String?
    public let last4: String?
    public let expirationMonth: String?
    public let expirationYear: String?
    public let availability: Availability?

    public init(
        id: String,
        type: String? = nil,
        cardType: String? = nil,
        brand: String? = nil,
        last4: String? = nil,
        expirationMonth: String? = nil,
        expirationYear: String? = nil,
        availability: Availability? = nil
    ) {
        self.id = id
        self.type = type
        self.cardType = cardType
        self.brand = brand
        self.last4 = last4
        self.expirationMonth = expirationMonth
        self.expirationYear = expirationYear
        self.availability = availability
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        cardType = try container.decodeIfPresent(String.self, forKey: .cardType)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        last4 = try container.decodeLenientStringIfPresent(forKey: .last4)
        expirationMonth = try container.decodeLenientStringIfPresent(forKey: .expirationMonth)
        expirationYear = try container.decodeLenientStringIfPresent(forKey: .expirationYear)
        availability = try container.decodeIfPresent(Availability.self, forKey: .availability)
    }
}
