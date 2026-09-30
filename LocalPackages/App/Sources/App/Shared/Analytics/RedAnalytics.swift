import Foundation
import TKCore
import TKLogging

final class RedAnalyticsSessionHolder {
    private let analytics: AnalyticsProvider
    private var session: RedAnalyticsSession?

    init(analytics: AnalyticsProvider) {
        self.analytics = analytics
    }

    func start(
        flow: OpAttempt.Flow,
        operation: OpAttempt.Operation,
        attemptSource: RedAnalyticsAttemptSource? = nil,
        otherMetadata: RedAnalyticsMetadata? = nil
    ) {
        guard session == nil else {
            return Log.w("cannot start red session which is already started")
        }
        let metadata = otherMetadata ?? [:]
        let session = RedAnalyticsSession(
            operationId: UUID().uuidString,
            flow: flow,
            operation: operation,
            attemptSource: attemptSource,
            startedAtMs: nowMs(),
            otherMetadata: metadata
        )

        analytics.log(
            OpAttempt(
                operationId: session.operationId,
                flow: flow,
                operation: operation,
                attemptSource: attemptSource?.rawValue,
                startedAtMs: session.startedAtMs,
                otherMetadata: metadata.asJsonString
            )
        )
        self.session = session
    }

    func finish(
        outcome: OpTerminal.Outcome,
        error: AnalyticsError? = nil,
        stage: String? = nil,
        otherMetadata: RedAnalyticsMetadata? = nil
    ) {
        guard let session else {
            return Log.w("cannot finish red session which is not started")
        }
        let finishedAtMs = nowMs()
        let error = outcome == .fail ? error : nil
        let metadata = otherMetadata ?? [:]

        analytics.log(
            OpTerminal(
                operationId: session.operationId,
                flow: session.flow.opTerminalValue,
                operation: session.operation.opTerminalValue,
                outcome: outcome,
                durationMs: Double(finishedAtMs - session.startedAtMs),
                finishedAtMs: finishedAtMs,
                errorCode: error?.code,
                errorMessage: error?.message,
                errorType: error?.type.rawValue,
                stage: stage,
                otherMetadata: metadata.asJsonString
            )
        )
        self.session = nil
    }

    private func nowMs() -> Int {
        Int(Date().timeIntervalSince1970 * 1000)
    }
}
