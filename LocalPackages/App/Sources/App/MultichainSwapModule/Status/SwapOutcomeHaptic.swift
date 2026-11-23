/// A finished swap is announced in the foreground both by its toast and by the Live Activity
/// monitor. The first to claim one of the swap's transactions plays the haptic, the other stays silent.
@MainActor
enum SwapOutcomeHaptic {
    private static var claimedTransactionIds = Set<String>()

    /// - Parameter transactionIds: Normalized with `MultichainTransactionID.normalized`.
    static func claim(transactionIds: Set<String>) -> Bool {
        guard claimedTransactionIds.isDisjoint(with: transactionIds) else { return false }
        claimedTransactionIds.formUnion(transactionIds)
        return true
    }
}
