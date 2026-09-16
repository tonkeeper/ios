public enum MultichainTransactionEmulationFailure: Error {
    case unsupportedChain(MultichainChain)
    case unsupportedAsset(id: String)
    case invalidSenderAddress(String)
    case invalidRecipientAddress(String)
    case chainError(
        kind: MultichainSwapExecutionErrorKind,
        reason: String
    )
    case `internal`(
        reason: String
    )

    var executionErrorKind: MultichainSwapExecutionErrorKind {
        if case let .chainError(kind, _) = self {
            return kind
        }
        return .unknown
    }
}
