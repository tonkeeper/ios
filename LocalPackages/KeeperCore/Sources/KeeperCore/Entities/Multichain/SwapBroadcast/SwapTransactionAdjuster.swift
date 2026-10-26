import ChainKit

/// Rebuilds a swap transaction with the amount returned by ChainKit's gas-reserve
/// calculation. Only an actual amount adjustment enables max transaction semantics, and
/// only `flex` calldata accepts one at all: an `exact` payload carries its amount inside
/// the calldata, so the transaction leaves with the quoted amount whatever the reserve
/// returned. The parts of a split route are never resized either.
enum SwapTransactionAdjuster {
    static func adjustedTransactions(
        _ transactions: [TransactionSwap],
        gasReserve: GasReserveResult,
        calldataType: MultichainSwapCalldataPayloadType
    ) -> [TransactionSwap] {
        guard calldataType == .flex,
              gasReserve.isAmountAdjusted,
              transactions.count == 1,
              let transaction = transactions.first
        else {
            return transactions
        }
        return [
            TransactionSwap(
                account: transaction.account,
                amount: gasReserve.amount,
                isMax: true,
                destination: transaction.destination,
                to: transaction.to,
                data: transaction.data,
                initData: transaction.initData,
                memo: transaction.memo
            ),
        ]
    }
}
