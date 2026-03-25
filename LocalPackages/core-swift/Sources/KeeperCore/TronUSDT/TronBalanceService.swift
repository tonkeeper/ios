import BigInt
import Foundation
import TKLogging
import TronSwift
import TronSwiftAPI

public protocol TronBalanceService {
    func loadBalance(address: Address, includingTransferFees: Bool) async throws -> TronBalance
}

public final class TronBalanceServiceImplementation: TronBalanceService {
    private let api: TronApi

    public init(api: TronApi) {
        self.api = api
    }

    public func loadBalance(address: Address, includingTransferFees: Bool) async throws -> TronBalance {
        async let usdtTask = api.tronUSDTBalance(owner: address)

        let balance: TronBalance
        if includingTransferFees {
            async let trxTask = api.tronBalance(owner: address)
            let (usdtAmount, trxAmount) = try await(usdtTask, trxTask)
            balance = TronBalance(
                amount: usdtAmount,
                trxAmount: trxAmount
            )
        } else {
            balance = try TronBalance(
                amount: await usdtTask,
                trxAmount: 0
            )
        }
        return balance
    }
}
