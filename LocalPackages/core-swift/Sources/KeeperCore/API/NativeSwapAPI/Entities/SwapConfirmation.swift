import Foundation
import TonSwift

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

    public init(
        messages: [SwapConfirmation.Message],
        quoteId: String,
        resolverName: String,
        askUnits: String,
        bidUnits: String,
        protocolFeeUnits: String,
        tradeStartDeadline: String,
        gasBudget: String,
        estimatedGasConsumption: String,
        slippage: Int
    ) {
        self.messages = messages
        self.quoteId = quoteId
        self.resolverName = resolverName
        self.askUnits = askUnits
        self.bidUnits = bidUnits
        self.protocolFeeUnits = protocolFeeUnits
        self.tradeStartDeadline = tradeStartDeadline
        self.gasBudget = gasBudget
        self.estimatedGasConsumption = estimatedGasConsumption
        self.slippage = slippage
    }

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

        public init(
            targetAddress: AnyAddress,
            sendAmount: String,
            payload: String
        ) {
            self.targetAddress = targetAddress
            self.sendAmount = sendAmount
            self.payload = payload
        }
    }
}
