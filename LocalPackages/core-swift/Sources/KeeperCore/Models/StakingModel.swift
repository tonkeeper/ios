import Foundation
import BigInt

public struct StakingModel {
    public let wallet: Wallet
    public let pool: PoolImplementation
    public let inputText: String
    public let convertedText: String
    
    public let amount: BigUInt
    public let token: Token
    
    public var sendItem: SendItem? {
        if let pool = pool.pools.first, let token = token.address {
            return .staking(pool: pool, token: token, amount: amount)
        }
        return nil
    }
    
    public var receipent: Recipient {
        .init(recipientAddress: .raw(.mock(workchain: 0, seed: "")), isMemoRequired: true)
    }
    
    public init(
        wallet: Wallet,
        pool: PoolImplementation,
        inputText: String,
        convertedText: String,
        amount: BigUInt,
        token: Token
    ) {
        self.wallet = wallet
        self.pool = pool
        self.inputText = inputText
        self.convertedText = convertedText
        self.amount = amount
        self.token = token
    }
}
