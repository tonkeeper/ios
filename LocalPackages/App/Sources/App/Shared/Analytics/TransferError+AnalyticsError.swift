import KeeperCore

extension TransferError: AnalyticsError {
    var type: RedAnalyticsErrorType {
        .transferFailed
    }

    var message: String {
        switch self {
        case .nothingToSend:
            "Nothing to send"
        case .unsupportedTransfer:
            "Unsupported Transfer"
        case let .failedToCreateTransferData(message):
            "Failed to create transfer data due to error: \(message ?? "unknown")"
        case .noExcessesAddress:
            "No Excesses Address"
        case .noJettonWalletAddress:
            "No Jetton Wallet Address"
        case let .sendFailed(message):
            message ?? "Send failed"
        }
    }

    var code: Int {
        switch self {
        case .nothingToSend:
            1
        case .unsupportedTransfer:
            2
        case .failedToCreateTransferData:
            3
        case .noExcessesAddress:
            4
        case .noJettonWalletAddress:
            5
        case .sendFailed:
            6
        }
    }
}
