import BigInt
import Foundation
import TronSwift

public struct EventTransaction: Decodable {
    public enum Error: Swift.Error {
        case invalidValue
    }

    public enum TransactionType: String, Decodable {
        case transfer = "Transfer"
    }

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case tokenInfo = "token_info"
        case timestamp = "block_timestamp"
        case from
        case to
        case type
        case value
    }

    public let transactionId: String
    public let tokenInfo: TokenInfo
    public let timestamp: Int64
    public let from: Address
    public let to: Address
    public let type: TransactionType
    public let value: BigUInt

    public init(
        transactionId: String,
        tokenInfo: TokenInfo,
        timestamp: Int64,
        from: Address,
        to: Address,
        type: TransactionType,
        value: BigUInt
    ) {
        self.transactionId = transactionId
        self.tokenInfo = tokenInfo
        self.timestamp = timestamp
        self.from = from
        self.to = to
        self.type = type
        self.value = value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        transactionId = try container.decode(String.self, forKey: .transactionId)
        tokenInfo = try container.decode(TokenInfo.self, forKey: .tokenInfo)
        timestamp = try container.decode(Int64.self, forKey: .timestamp)

        let rawFromAddress = try container.decode(String.self, forKey: .from)
        from = try Address(address: rawFromAddress)

        let rawToAddress = try container.decode(String.self, forKey: .to)
        to = try Address(address: rawToAddress)

        type = try container.decode(TransactionType.self, forKey: .type)

        let rawValue = try container.decode(String.self, forKey: .value)
        guard let value = BigUInt(rawValue) else {
            throw Error.invalidValue
        }
        self.value = value
    }
}
