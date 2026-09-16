enum MultichainSwapPreparedPayloadKind: Hashable {
    case approval
    case main
    case other(String)

    init(rawValue: String) {
        switch rawValue {
        case "approval":
            self = .approval
        case "main":
            self = .main
        default:
            self = .other(rawValue)
        }
    }
}

extension MultichainSwapPreparedPayload {
    var payloadKind: MultichainSwapPreparedPayloadKind {
        MultichainSwapPreparedPayloadKind(rawValue: kind)
    }
}
