import Foundation
import TKCore
import TKLogging

@MainActor
final class PerpsFundingLifecycle: AppStateTrackerObserver, ReachabilityTrackerObserver {
    let states: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation
    private let appState: AppStateTracker
    private let reachability: ReachabilityTracker
    private var lastPublished: Bool?

    init(appState: AppStateTracker, reachability: ReachabilityTracker) {
        self.appState = appState
        self.reachability = reachability
        var continuation: AsyncStream<Bool>.Continuation!
        states = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation = $0 }
        self.continuation = continuation
        appState.addObserver(self)
        reachability.addObserver(self)
        publish()
    }

    deinit {
        continuation.finish()
    }

    nonisolated func didUpdateState(_ state: AppStateTracker.State) {
        Task { @MainActor [weak self] in self?.publish() }
    }

    nonisolated func didUpdateState(_ state: ReachabilityTracker.State) {
        Task { @MainActor [weak self] in self?.publish() }
    }

    private func publish() {
        let enabled = appState.state != .background && reachability.state == .connected
        if lastPublished != enabled {
            PerpsOperationLog.event("lifecycle", outcome: enabled ? "active" : "paused", fields: ["app_state": String(describing: appState.state), "reachability": String(describing: reachability.state)])
            lastPublished = enabled
        }
        continuation.yield(enabled)
    }
}
