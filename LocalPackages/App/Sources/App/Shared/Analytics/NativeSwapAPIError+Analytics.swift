import KeeperCore

extension NativeSwapAPIError: AnalyticsError {
    var type: RedAnalyticsErrorType {
        .nativeSwap
    }

    var message: String {
        switch self {
        case let .incorrectHost(host):
            "Incorrect host: \(host)"
        case let .streamingFailed(message):
            "Streaming failed, reason: \(message ?? "unknown")"
        case .serverError:
            "Server error"
        }
    }

    var code: Int {
        switch self {
        case .incorrectHost:
            return 1
        case .streamingFailed:
            return 2
        case .serverError:
            return 3
        }
    }
}
