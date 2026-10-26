/// `native` is the source chain's own coin through ChainKit's own broadcast; `battery`, `gram` and
/// `token` travel through a relayer instead, which bills its charges, the wallet's GRAM or a token
/// of the source chain.
@frozen public enum MultichainSwapFeeMethod: Sendable, Hashable {
    case native
    case battery
    case gram
    /// A relayer billed in a token of the source chain, named by the wallet's id of that token.
    case token(assetId: String)

    /// A stable name for logs, analytics and the rows of the fee picker.
    public var id: String {
        switch self {
        case .native:
            "native"
        case .battery:
            "battery"
        case .gram:
            "gram"
        case let .token(assetId):
            "\(Self.tokenPrefix)\(assetId)"
        }
    }

    public init?(id: String) {
        switch id {
        case "native":
            self = .native
        case "battery":
            self = .battery
        case "gram":
            self = .gram
        default:
            guard id.hasPrefix(Self.tokenPrefix) else {
                return nil
            }
            self = .token(assetId: String(id.dropFirst(Self.tokenPrefix.count)))
        }
    }

    private static let tokenPrefix = "token:"
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
