/// `native` is the source chain's own coin through ChainKit's own broadcast; `battery` and `gram`
/// travel through a relayer instead, which bills its charges or the wallet's GRAM.
public enum MultichainSwapFeeMethod: String, Sendable, Hashable {
    case native
    case battery
    case gram
}

public extension MultichainSwapFeeMethod {
    var isBattery: Bool {
        self == .battery
    }

    /// Everything but the chain's own coin is signed here and handed to the relayer, which decides
    /// both whether a failed send may be retried and where an unpayable method's way out leads.
    var isRelayed: Bool {
        self != .native
    }
}
