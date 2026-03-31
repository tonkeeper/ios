import Foundation

public struct BalanceOfMethod: ContractMethod {
    private let owner: Address
    public init(owner: Address) {
        self.owner = owner
    }

    public var signature: String {
        "balanceOf(address)"
    }

    public var arguments: [Parameter] {
        [.address(owner)]
    }
}
