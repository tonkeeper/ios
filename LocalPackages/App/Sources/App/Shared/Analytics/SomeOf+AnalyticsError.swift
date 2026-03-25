import KeeperCore

extension SomeOf: AnalyticsError where First: AnalyticsError, Second: AnalyticsError {
    var type: RedAnalyticsErrorType {
        switch self {
        case let .firstOption(first):
            first.type
        case let .secondOption(second):
            second.type
        }
    }

    var message: String {
        switch self {
        case let .firstOption(first):
            first.message
        case let .secondOption(second):
            second.message
        }
    }

    var code: Int {
        switch self {
        case let .firstOption(first):
            first.code
        case let .secondOption(second):
            second.code
        }
    }
}
