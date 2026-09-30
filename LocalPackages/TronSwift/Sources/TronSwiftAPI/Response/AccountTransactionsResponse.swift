import BigInt
import Foundation
import TronSwift

/// `v1/accounts/{address}/transactions` lists every contract type the account took part in; only a
/// `TransferContract` moves TRX, so any other transaction decodes with `transfer == nil`.
public struct AccountTransactionsResponse: Decodable {
    public struct Transaction: Decodable {
        public struct Transfer {
            public let from: Address
            public let to: Address
            public let amountSun: BigUInt
        }

        public let txID: String
        public let timestamp: Int64
        public let isFailed: Bool
        public let transfer: Transfer?

        enum CodingKeys: String, CodingKey {
            case txID
            case timestamp = "block_timestamp"
            case ret
            case rawData = "raw_data"
        }

        private struct Result: Decodable {
            let contractRet: String?
        }

        private struct RawData: Decodable {
            let contract: [Contract]
        }

        private struct Contract: Decodable {
            struct Parameter: Decodable {
                struct Value: Decodable {
                    let ownerAddress: String?
                    let toAddress: String?
                    let amount: Int64?

                    enum CodingKeys: String, CodingKey {
                        case ownerAddress = "owner_address"
                        case toAddress = "to_address"
                        case amount
                    }
                }

                let value: Value
            }

            let type: String
            let parameter: Parameter
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            txID = try container.decode(String.self, forKey: .txID)
            timestamp = try container.decode(Int64.self, forKey: .timestamp)

            let contractRet = try container.decodeIfPresent([Result].self, forKey: .ret)?.first?.contractRet
            isFailed = contractRet.map { $0 != "SUCCESS" } ?? false

            let contract = try container.decode(RawData.self, forKey: .rawData).contract.first
            guard let contract, contract.type == "TransferContract" else {
                transfer = nil
                return
            }
            let value = contract.parameter.value
            guard let ownerAddress = value.ownerAddress,
                  let toAddress = value.toAddress,
                  let amount = value.amount, amount >= 0
            else {
                throw DecodingError.dataCorruptedError(
                    forKey: .rawData,
                    in: container,
                    debugDescription: "TransferContract without owner, recipient or amount"
                )
            }
            transfer = try Transfer(
                from: Self.address(hex: ownerAddress, container: container),
                to: Self.address(hex: toAddress, container: container),
                amountSun: BigUInt(amount)
            )
        }

        private static func address(
            hex: String,
            container: KeyedDecodingContainer<CodingKeys>
        ) throws -> Address {
            guard let raw = Data(strictHex: hex) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .rawData,
                    in: container,
                    debugDescription: "Address is not hex: \(hex)"
                )
            }
            return try Address(raw: raw)
        }
    }

    public let data: [Transaction]
    public let fingerprint: String?

    enum CodingKeys: CodingKey {
        case data
        case meta
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode([Transaction].self, forKey: .data)
        fingerprint = try container.decode(TransactionsResponse.Meta.self, forKey: .meta).fingerprint
    }
}
