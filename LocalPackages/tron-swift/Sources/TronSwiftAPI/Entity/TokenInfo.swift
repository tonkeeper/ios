import Foundation
import TronSwift

public struct TokenInfo: Decodable {
    public let symbol: String
    public let address: Address
    public let decimals: Int
    public let name: String

    enum CodingKeys: String, CodingKey {
        case symbol
        case address
        case decimals
        case name
    }

    public init(
        symbol: String,
        address: Address,
        decimals: Int,
        name: String
    ) {
        self.symbol = symbol
        self.address = address
        self.decimals = decimals
        self.name = name
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(String.self, forKey: .symbol)
        decimals = try container.decode(Int.self, forKey: .decimals)
        name = try container.decode(String.self, forKey: .name)

        let rawAddress = try container.decode(String.self, forKey: .address)
        address = try Address(address: rawAddress)
    }
}
