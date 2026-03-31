import BigInt
import Foundation

public struct TransferMethod: ContractMethod {
    private let to: Address
    private let amount: BigUInt
    public init(
        to: Address,
        amount: BigUInt
    ) {
        self.to = to
        self.amount = amount
    }

    public var signature: String {
        "transfer(address,uint256)"
    }

    public var arguments: [Parameter] {
        [.address(to), .bigUInt(amount)]
    }
}
