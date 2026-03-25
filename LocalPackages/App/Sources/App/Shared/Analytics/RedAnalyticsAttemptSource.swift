public struct RedAnalyticsAttemptSource: ExpressibleByStringLiteral, Hashable {
    var rawValue: String

    public init(stringLiteral: String) {
        self.rawValue = stringLiteral
    }
}

public extension RedAnalyticsAttemptSource {
    static let nativeUI: RedAnalyticsAttemptSource = "native_ui"
    static let tonconnectLocal: RedAnalyticsAttemptSource = "tonconnect_local"
    static let tonconnectRemote: RedAnalyticsAttemptSource = "tonconnect_remote"
}
