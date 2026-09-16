/// Executable payload set of a validated route: exactly one main transaction,
/// optionally preceded by an ERC20 approval. Makes the structural invariant and
/// the broadcast order unrepresentable to violate.
public enum MultichainSwapRoutePayloads: Sendable, Hashable {
    case main(MultichainSwapPreparedPayload)
    case approvalThenMain(approval: MultichainSwapPreparedPayload, main: MultichainSwapPreparedPayload)

    public var main: MultichainSwapPreparedPayload {
        switch self {
        case let .main(main), let .approvalThenMain(_, main):
            return main
        }
    }

    public var approval: MultichainSwapPreparedPayload? {
        switch self {
        case .main:
            return nil
        case let .approvalThenMain(approval, _):
            return approval
        }
    }

    /// Payloads in broadcast order.
    public var all: [MultichainSwapPreparedPayload] {
        switch self {
        case let .main(main):
            return [main]
        case let .approvalThenMain(approval, main):
            return [approval, main]
        }
    }
}
