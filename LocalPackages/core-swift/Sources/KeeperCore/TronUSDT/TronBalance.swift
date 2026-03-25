import BigInt
import Foundation

public struct TronBalance: Codable, Equatable {
    public let amount: BigUInt
    public let trxAmount: BigUInt

    public init(amount: BigUInt, trxAmount: BigUInt) {
        self.amount = amount
        self.trxAmount = trxAmount
    }
}
