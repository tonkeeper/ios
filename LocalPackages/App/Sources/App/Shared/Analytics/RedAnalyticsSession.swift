import TKCore

public typealias RedAnalyticsMetadata = [RedAnalyticsMetadataKey: Any?]

struct RedAnalyticsSession {
    var operationId: String
    var flow: OpAttempt.Flow
    var operation: OpAttempt.Operation
    var attemptSource: RedAnalyticsAttemptSource?
    var startedAtMs: Int
    var otherMetadata: RedAnalyticsMetadata?
}
