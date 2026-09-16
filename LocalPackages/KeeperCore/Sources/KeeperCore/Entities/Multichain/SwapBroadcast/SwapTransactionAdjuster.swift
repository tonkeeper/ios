import ChainKit

/// Rebuilds a swap transaction with the amount returned by ChainKit's gas-reserve
/// calculation. Only an actual amount adjustment enables max transaction semantics, and
/// only `flex` calldata accepts one at all: an `exact` payload carries its amount inside
/// the calldata, so the transaction leaves with the quoted amount whatever the reserve
/// returned.
enum SwapTransactionAdjuster {
    static func adjustedTransaction(
        _ transaction: TransactionSwap,
        gasReserve: GasReserveResult,
        calldataType: MultichainSwapCalldataPayloadType
    ) -> TransactionSwap {
        guard calldataType == .flex, gasReserve.isAmountAdjusted else {
            return transaction
        }
        return TransactionSwap(
            account: transaction.account,
            amount: gasReserve.amount,
            energy: transaction.energy,
            isMax: true,
            destination: transaction.destination,
            to: transaction.to,
            data: transaction.data,
            initData: transaction.initData
        )
    }
}
