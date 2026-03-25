import TKCore

public struct RedAnalyticsConfiguration {
    public var flow: OpAttempt.Flow
    public var operation: OpAttempt.Operation
    public var attemptSource: RedAnalyticsAttemptSource?
    public var staticMetadata: RedAnalyticsMetadata
}
