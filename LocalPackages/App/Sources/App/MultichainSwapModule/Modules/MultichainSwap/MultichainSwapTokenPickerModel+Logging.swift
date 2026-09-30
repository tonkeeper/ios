extension MultichainSwapTokenPickerSide: CustomStringConvertible {
    var description: String {
        switch self {
        case .source:
            return "source"
        case .receive:
            return "receive"
        }
    }
}

extension TokenPickerV2ChainFilter: CustomStringConvertible {
    var description: String {
        switch self {
        case .all:
            return "all"
        case let .chain(chain):
            return chain.rawValue
        case .perpetuals:
            return "perpetuals"
        }
    }
}
