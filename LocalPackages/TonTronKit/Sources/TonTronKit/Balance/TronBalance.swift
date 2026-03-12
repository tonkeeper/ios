import BigInt
import Foundation

public struct TronBalance: Codable, Equatable {
    public let amount: BigUInt

    public init(amount: BigUInt) {
        self.amount = amount
    }
}
