@preconcurrency import ChainKit

/// What a flow is about to sign, as the gate's checks read it. A review that is only logged reads it
/// in a task of its own while the flow signs: chain-kit's operations are immutable, and every review
/// builds the account it reads.
struct SignableOperation: Sendable {
    /// How what is reviewed relates to what is signed.
    enum Fidelity: String {
        /// The reviewed operation itself is signed.
        case exact
        /// The reviewed operation wraps exactly the bytes that are signed.
        case exactWrap
        /// The reviewed operation is a copy built from the inputs of what is signed.
        case converted
    }

    let operation: ChainKit.Operation
    /// The account of the spent asset, at the address that signs.
    let account: ChainKit.Account
    let intent: OperationIntent
    let fidelity: Fidelity
}
