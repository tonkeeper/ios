import KeeperCore

extension SignDataRequestFailure: AnalyticsError {
    var type: RedAnalyticsErrorType {
        .signRequestFailed
    }

    var message: String {
        switch self {
        case let .confirmationFailed(message):
            "Failed to confirm sign data request due to error: \(message ?? "unknown")"
        }
    }

    var code: Int {
        switch self {
        case .confirmationFailed:
            1
        }
    }
}
