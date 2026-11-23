import FirebaseRemoteConfig
import TKFeatureFlags
import TKLogging
import UIKit

/// `RemoteConfig.remoteConfig()` blocks its caller until the config database opens,
/// so the provider opens and activates the config in one task off the main thread.
public final class TKFirebaseRemoteConfigProvider {
    /// Longer than a slow but healthy activation, which can take a few seconds.
    private static let activationTimeoutMs: UInt64 = 10000

    private let requestTimeoutMs: UInt64
    private let lock = NSLock()
    private var loadTask: Task<Void, Never>?
    private var isLoadFinished = false
    private var runningFetch: Task<Void, Error>?
    private var activated: (remoteConfig: RemoteConfig, keys: Set<String>)?

    public init(
        requestTimeoutMs: UInt64
    ) {
        self.requestTimeoutMs = requestTimeoutMs
    }

    /// Starts the load once. Call it right after `FirebaseApp.configure()`; `load()` awaits the same task.
    /// A load that ended unactivated, e.g. a first launch past its fetch deadline, starts again, so a
    /// reconnected scene activates the fetch that ended since. A restart joins a fetch that still runs.
    public func startLoading() {
        lock.withLock {
            guard loadTask == nil || (isLoadFinished && activated == nil) else { return }
            isLoadFinished = false
            loadTask = Task(priority: .userInitiated) {
                await performLoad()
                lock.withLock { isLoadFinished = true }
            }
        }
    }
}

extension TKFirebaseRemoteConfigProvider: RemoteConfigProvider {
    public func load() async {
        startLoading()
        await lock.withLock { loadTask }?.value
    }

    public subscript(_ flag: String) -> Bool? {
        guard let activated = lock.withLock({ activated }), activated.keys.contains(flag) else {
            return nil
        }
        return activated.remoteConfig.configValue(forKey: flag).boolValue
    }
}

extension TKFirebaseRemoteConfigProvider {
    enum DeadlineOutcome {
        case finished
        case failed(Error)
        case deadlineExceeded
    }

    /// Races a Firebase call against the deadline. A task group would wait for the call past the deadline,
    /// because the Firebase calls ignore cancellation. The call goes on after the deadline; its result reaches the
    /// flags only through a restarted load or the next launch.
    static func withDeadline(
        ms deadlineMs: UInt64,
        _ work: @escaping @Sendable () async throws -> Void
    ) async -> DeadlineOutcome {
        let (outcomes, continuation) = AsyncStream.makeStream(of: DeadlineOutcome.self)
        Task {
            do {
                try await work()
                continuation.yield(.finished)
            } catch {
                continuation.yield(.failed(error))
            }
        }
        let deadline = Task {
            try? await Task.sleep(nanoseconds: deadlineMs * NSEC_PER_MSEC)
            continuation.yield(.deadlineExceeded)
        }
        defer {
            continuation.finish()
            deadline.cancel()
        }
        for await outcome in outcomes {
            return outcome
        }
        return .deadlineExceeded
    }
}

private extension TKFirebaseRemoteConfigProvider {
    @concurrent
    func performLoad() async {
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 600
        remoteConfig.configSettings = settings

        let waitForFetchBeforeActivate = remoteConfig.lastFetchStatus == .noFetchYet
        Log.i("loading remote config, waitForFetchBeforeActivate=\(waitForFetchBeforeActivate)")
        if waitForFetchBeforeActivate {
            let fetch = lock.withLock {
                if let runningFetch { return runningFetch }
                let task = Task {
                    defer { lock.withLock { runningFetch = nil } }
                    _ = try await remoteConfig.fetch()
                }
                runningFetch = task
                return task
            }
            switch await Self.withDeadline(ms: requestTimeoutMs, { try await fetch.value }) {
            case .finished:
                Log.i("remote config fetched")
                await activate(remoteConfig)
            case let .failed(error):
                Log.w("failed to fetch remote config", extraInfo: ["failureReason": "\(error)"])
            case .deadlineExceeded:
                Log.w("remote config fetch deadline exceeded")
            }
        } else {
            await activate(remoteConfig)
            Task {
                do {
                    try await remoteConfig.fetch()
                    Log.i("remote config fetched")
                } catch {
                    Log.w("failed to fetch remote config", extraInfo: ["failureReason": "\(error)"])
                }
            }
        }
    }

    /// Firebase can hold an activation for a minute or longer: on the launch after a fresh install that was closed
    /// before its first fetch was activated. The launch waits for it only up to its own deadline. This call does not
    /// publish a late result, so the flags do not change under a running UI; a restarted load activates again.
    func activate(_ remoteConfig: RemoteConfig) async {
        switch await Self.withDeadline(ms: Self.activationTimeoutMs, { _ = try await remoteConfig.activate() }) {
        case .finished:
            break
        case let .failed(error):
            Log.w("failed to activate remote config", extraInfo: ["failureReason": "\(error)"])
            return
        case .deadlineExceeded:
            Log.w("remote config activation deadline exceeded")
            return
        }
        let keys = Set(remoteConfig.allKeys(from: .remote))
        lock.withLock { activated = (remoteConfig, keys) }
        Log.i("remote config activated, keys: [\(keys.joined(separator: ", "))]")
    }
}
