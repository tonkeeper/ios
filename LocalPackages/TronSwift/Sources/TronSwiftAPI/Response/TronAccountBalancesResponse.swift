import BigInt
import Foundation

public struct TronAccountBalances: Equatable {
    public let trxAmount: BigUInt
    public let usdtAmount: BigUInt

    public init(trxAmount: BigUInt, usdtAmount: BigUInt) {
        self.trxAmount = trxAmount
        self.usdtAmount = usdtAmount
    }
}

struct TronAccountBalancesResponse: Decodable {
    struct Account: Decodable {
        let balance: DirtyBigInt?
        let trc20: [[String: DirtyBigInt]]?
    }

    let data: [Account]

    func balances(usdtContractAddress: String) -> TronAccountBalances {
        guard let account = data.first else {
            return TronAccountBalances(trxAmount: 0, usdtAmount: 0)
        }

        let trxAmount = max(0, account.balance?.bigIntValue ?? 0)
        let usdtAmount = max(
            0,
            account.trc20?
                .lazy
                .compactMap { balances in
                    balances.first {
                        $0.key.caseInsensitiveCompare(usdtContractAddress) == .orderedSame
                    }?.value.bigIntValue
                }
                .first ?? 0
        )
        return TronAccountBalances(
            trxAmount: BigUInt(trxAmount),
            usdtAmount: BigUInt(usdtAmount)
        )
    }
}
