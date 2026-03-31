import Foundation
import KeeperCore

protocol AnalyticsError {
    var type: RedAnalyticsErrorType { get }
    var message: String { get }
    var code: Int { get }
}

struct AnyAnalyticsError: AnalyticsError {
    let type: RedAnalyticsErrorType
    let message: String
    let code: Int
}
