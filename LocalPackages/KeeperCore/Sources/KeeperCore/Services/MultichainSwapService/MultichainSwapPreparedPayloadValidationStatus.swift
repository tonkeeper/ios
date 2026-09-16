enum MultichainSwapPreparedPayloadValidationStatus: Sendable, Hashable {
    case validated
    case other(String)

    init(rawValue: String) {
        switch rawValue {
        case "validated":
            self = .validated
        default:
            self = .other(rawValue)
        }
    }
}

extension MultichainSwapPreparedPayload {
    var payloadValidationStatus: MultichainSwapPreparedPayloadValidationStatus {
        MultichainSwapPreparedPayloadValidationStatus(rawValue: validationStatus)
    }
}
