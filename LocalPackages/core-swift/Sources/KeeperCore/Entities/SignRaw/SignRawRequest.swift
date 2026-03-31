import Foundation
import TonSwift

public struct SignRawRequest: Decodable {
    public let messages: [SignRawRequestMessage]
    public let validUntil: UInt64?
    public let from: Address?
    public let messagesVariants: MessagesVariants?

    public struct MessagesVariants: Decodable {
        public let battery: [SignRawRequestMessage]
    }

    enum CodingKeys: String, CodingKey {
        case messages
        case messagesVariants
        case validUntil = "valid_until"
        case from
        case source
    }

    public init(
        messages: [SignRawRequestMessage],
        validUntil: UInt64?,
        from: Address?,
        messagesVariants: MessagesVariants?
    ) {
        self.messages = messages
        self.validUntil = validUntil
        self.from = from
        self.messagesVariants = messagesVariants
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messages = try container.decode([SignRawRequestMessage].self, forKey: .messages)
        validUntil = try? container.decodeIfPresent(UInt64.self, forKey: .validUntil)

        messagesVariants = try? container.decode(MessagesVariants.self, forKey: .messagesVariants)

        if let fromValue = try? container.decode(String.self, forKey: .from) {
            from = try Address.parse(fromValue)
        } else {
            from = try Address.parse(container.decode(String.self, forKey: .source))
        }
    }
}

public struct SignRawRequestMessage: Decodable {
    public let address: AnyAddress
    public let amount: UInt64
    public let stateInit: String?
    public let payload: String?

    enum CodingKeys: String, CodingKey {
        case address
        case amount
        case stateInit
        case payload
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.address = try container.decode(AnyAddress.self, forKey: .address)
        self.stateInit = try container.decodeIfPresent(String.self, forKey: .stateInit)
        self.payload = try container.decodeIfPresent(String.self, forKey: .payload)

        if let amountString = try? container.decode(String.self, forKey: .amount) {
            amount = UInt64(amountString) ?? 0
        } else {
            amount = try container.decode(UInt64.self, forKey: .amount)
        }
    }

    public init(
        address: AnyAddress,
        amount: UInt64,
        stateInit: String?,
        payload: String?
    ) {
        self.address = address
        self.amount = amount
        self.stateInit = stateInit
        self.payload = payload
    }
}
