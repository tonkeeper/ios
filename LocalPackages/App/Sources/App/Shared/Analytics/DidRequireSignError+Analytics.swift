import Foundation

extension DidRequireSignError: AnalyticsError {
    var type: RedAnalyticsErrorType {
        .signRequired
    }

    var message: String {
        switch self {
        case .unknown:
            return "Failed to request signing"
        }
    }

    var code: Int {
        switch self {
        case .unknown:
            1
        }
    }
}
