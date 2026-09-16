import BigInt
import Foundation
import TonSwift

public enum NativeSwapConstants {
    public static let tonFeeReserve = BigUInt(1_000_000_000)

    public static var tonFeeReserveWholeUnits: BigUInt {
        tonFeeReserve / BigUInt(10).power(TonInfo.fractionDigits)
    }
}

public struct SwapConfirmation: Decodable {
    public let messages: [SwapConfirmation.Message]
    public let quoteId: String
    public let resolverName: String
    public let askUnits: String
    public let bidUnits: String
    public let protocolFeeUnits: String
    public let tradeStartDeadline: String
    public let gasBudget: String
    public let estimatedGasConsumption: String
    public let slippage: Int
    public let valueDifferenceBps: Int?

    public struct Message: Decodable {
        public let targetAddress: AnyAddress
        public let sendAmount: String
        public let payload: String

        enum CodingKeys: String, CodingKey {
            case targetAddress
            case sendAmount
            case payload
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let addressString = try container.decode(String.self, forKey: .targetAddress)
            targetAddress = try AnyAddress.address(Address.parse(addressString))

            if let sendAmountString = try? container.decode(String.self, forKey: .sendAmount) {
                sendAmount = sendAmountString
            } else {
                sendAmount = try String(container.decode(Int64.self, forKey: .sendAmount))
            }

            payload = try container.decode(String.self, forKey: .payload)
        }
    }
}

public extension SwapConfirmation {
    var requiredGasAmount: BigUInt {
        max(BigUInt(gasBudget) ?? 0, BigUInt(estimatedGasConsumption) ?? 0)
    }
}
