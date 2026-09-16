@preconcurrency import BigInt

/// A TRON swap that is nothing but a transfer of the source asset to the aggregator's deposit
/// address — the only shape a relayer can rebuild, since it signs its own transaction.
struct TronSwapTransfer: Sendable, Hashable {
    let to: String
    let amount: BigUInt
}
