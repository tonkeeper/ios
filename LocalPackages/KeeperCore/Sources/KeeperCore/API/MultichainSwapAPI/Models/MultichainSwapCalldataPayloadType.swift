import SwapAPI

/// How an aggregator's calldata relates to the amount the wallet sends, as the backend reports it
/// per payload.
public enum MultichainSwapCalldataPayloadType: String, Sendable, Hashable {
    /// The sell amount is baked into the calldata: the wallet must send exactly the quoted amount.
    /// Trimming it — say, to leave room for the fee on a max send — desyncs `value` from the
    /// calldata and the router reverts.
    case exact
    /// A plain deposit-style transfer: the wallet may lower the amount.
    case flex
}

extension MultichainSwapCalldataPayloadType {
    init(api: SwapAPI.Components.Schemas.CrossSwapCalldataPayloadType) {
        switch api {
        case .exact:
            self = .exact
        case .flex:
            self = .flex
        }
    }
}
