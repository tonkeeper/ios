/// `native` is the source chain's own coin through ChainKit's own broadcast; `battery` travels
/// through a relayer instead.
public enum MultichainSwapFeeMethod: String, Sendable, Hashable {
    case native
    case battery
}

public extension MultichainSwapFeeMethod {
    var isBattery: Bool {
        self == .battery
    }
}
