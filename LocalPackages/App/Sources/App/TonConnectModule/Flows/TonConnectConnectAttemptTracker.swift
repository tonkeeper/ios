import TKCore

final class TonConnectConnectAttemptTracker {
    private let session: RedAnalyticsSessionHolder
    private let attemptSource: RedAnalyticsAttemptSource
    private let isSafeMode: Bool

    init(
        makeSession: @escaping () -> RedAnalyticsSessionHolder,
        attemptSource: RedAnalyticsAttemptSource,
        isSafeMode: Bool
    ) {
        session = makeSession()
        self.attemptSource = attemptSource
        self.isSafeMode = isSafeMode
    }

    func start(manifestHost: String, returnStrategy: String?) {
        session.start(
            flow: .tonConnect,
            operation: .connectWallet,
            attemptSource: attemptSource,
            otherMetadata: [
                .dappHost: manifestHost,
                "return_strategy": returnStrategy,
                "is_safe_mode": isSafeMode,
            ]
        )
    }

    func finishSuccess() {
        session.finish(
            outcome: .success,
            stage: "connect_wallet"
        )
    }

    func finishFailure(_ error: Error) {
        session.finish(
            outcome: .fail,
            error: AnyAnalyticsError(
                type: .tonConnectSessionInterrupted,
                message: "underlying error: \(error.localizedDescription)",
                code: 1
            ),
            stage: "connect_wallet"
        )
    }

    func finishCancel() {
        session.finish(
            outcome: .cancel,
            stage: "connect_wallet"
        )
    }
}
