import TKLogging

extension TransferError: LoggableError {
    public var logDescription: String {
        let description = LogDescription(type: TransferError.self)
        switch self {
        case .nothingToSend:
            return description.with("case", "nothingToSend").text
        case .unsupportedTransfer:
            return description.with("case", "unsupportedTransfer").text
        case let .failedToCreateTransferData(message):
            return description.with("case", "failedToCreateTransferData").with("message", message).text
        case .noExcessesAddress:
            return description.with("case", "noExcessesAddress").text
        case .noJettonWalletAddress:
            return description.with("case", "noJettonWalletAddress").text
        case let .sendFailed(message, _):
            return description.with("case", "sendFailed").with("message", message).text
        }
    }
}
