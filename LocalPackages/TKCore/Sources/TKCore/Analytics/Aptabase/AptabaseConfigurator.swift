import Aptabase
import Foundation
import UIKit

public final class AptabaseConfigurator {
    public static let configurator = AptabaseConfigurator()

    private var endpointState = EndpointState()
    private var trackingOverride: Bool?

    private init() {}

    private func configure(sendStatsImmediately: Bool?) {
        trackingOverride = sendStatsImmediately
        endpointState.active = InfoProvider.aptabaseEndpoint()
        observeLifecycle()
        initializeSDK(endpoint: endpointState.active)
    }

    static func usableEndpoint(_ endpoint: String?) -> String? {
        guard let endpoint,
              let url = URL(string: endpoint),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty
        else { return nil }
        return endpoint
    }

    func retarget(endpointProvider: @escaping () -> String?) {
        DispatchQueue.main.async {
            if let endpoint = self.endpointState.request(
                endpointProvider(),
                bundledEndpoint: InfoProvider.aptabaseEndpoint()
            ) {
                self.replaceSDK(endpoint: endpoint)
            }
        }
    }

    private func observeLifecycle() {
        let center = NotificationCenter.default
        _ = center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.endpointState.isPolling = true
        }
        _ = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.endpointState.isPolling = false
            // Let the SDK's background observer stop its timer before replacing the client.
            DispatchQueue.main.async {
                guard let self, let endpoint = self.endpointState.applyPending() else { return }
                self.replaceSDK(endpoint: endpoint)
            }
        }
    }

    private func replaceSDK(endpoint: String) {
        NotificationCenter.default.removeObserver(Aptabase.shared)
        initializeSDK(endpoint: endpoint)
    }

    private func initializeSDK(endpoint: String?) {
        guard let appKey = InfoProvider.aptabaseKey() else { return }
        Aptabase.shared.initialize(
            appKey: appKey,
            with: InitOptions(
                host: endpoint,
                trackingMode: trackingOverride.map { $0 ? .asDebug : .asRelease } ?? .readFromEnvironment
            )
        )
    }

    struct EndpointState {
        var active: String?
        var isPolling = false
        private(set) var pending: String?

        mutating func request(_ remoteEndpoint: String?, bundledEndpoint: String?) -> String? {
            let endpoint = AptabaseConfigurator.usableEndpoint(remoteEndpoint) ?? bundledEndpoint
            pending = endpoint != active ? endpoint : nil
            return applyPending()
        }

        mutating func applyPending() -> String? {
            // The SDK cannot retire a running timer through its public API. Swap after backgrounding.
            guard !isPolling, let pending else { return nil }
            active = pending
            self.pending = nil
            return pending
        }
    }

    /// Falls back to the SDK when the persistent cache is disabled or the app is missing its Aptabase
    /// configuration.
    func makeAnalyticsService(
        persistentCacheEnabled: Bool,
        cohortSource: AptabaseCohortSource,
        installId: String,
        sendStatsImmediately: Bool?,
        reachabilityTracker: ReachabilityTracker,
        remoteEndpoint: @escaping @Sendable () -> String?
    ) -> AnalyticsService {
        let sequence = AnalyticsEventSequence(installId: installId)
        var environment = AptabaseEnvironment.current()
        if let sendStatsImmediately {
            environment.isDebug = sendStatsImmediately
        }

        guard persistentCacheEnabled,
              let bundledEndpoint = InfoProvider.aptabaseEndpoint(),
              let appKey = InfoProvider.aptabaseKey()
        else {
            // The flag is a kill switch, so a queue left by a previous run has to go: on this branch
            // nothing would ever send it, and it would sit on disk until its TTL.
            AptabaseEventStore.purge(configuration: .default())
            DispatchQueue.main.async {
                self.configure(sendStatsImmediately: sendStatsImmediately)
            }
            return AptabaseService(sequence: sequence, cohortSource: cohortSource)
        }

        let client = AptabaseQueueClient(
            store: AptabaseEventStore(configuration: .default()),
            dispatcher: AptabaseDispatcher(
                endpointProvider: { Self.usableEndpoint(remoteEndpoint()) ?? bundledEndpoint },
                appKey: appKey,
                environment: environment,
                session: URLSession.shared
            ),
            environment: environment,
            flushInterval: environment.isDebug ? 2 : 60
        )
        return AptabaseQueuedService(
            client: client,
            sequence: sequence,
            cohortSource: cohortSource,
            reachabilityTracker: reachabilityTracker
        )
    }
}

enum AptabaseTransport: String {
    case sdk
    case cache
}

/// Where the transport choice came from. Only `remote` is a cohort assignment: `default` means the remote
/// config never resolved and `defaultValue` picked the SDK, so the install lands in the `sdk` cohort
/// without Firebase ever having assigned it there. Mixing those two into one cohort compares populations
/// instead of transports, because `cache` is unreachable without a resolved remote value.
enum AptabaseCohortSource: String {
    case remote
    case `default`
    case override

    /// Mirrors the resolution order of `TKFeatureFlagsImplementation.subscript`: an override beats the
    /// remote value, which beats the default. A remote `false` is still an assignment.
    init(devOverride: Bool?, remoteValue: Bool?) {
        if devOverride != nil {
            self = .override
        } else if remoteValue != nil {
            self = .remote
        } else {
            self = .default
        }
    }
}

enum AptabaseTransportProperty {
    /// Monotonic per-install counter. Gaps in it are lost events, which is how the two transports are compared.
    static let sequence = "event_seq"
    static let transport = "analytics_transport"
    /// Scopes `event_seq`, which restarts from zero after a reinstall while `firebase_user_id` lives in
    /// the keychain and survives one — grouping by that alone would splice two overlapping ranges into
    /// a single install and let values from one install mask gaps in the other.
    static let installId = "analytics_install_id"
    /// Separates a real cohort assignment from a fallback and from our own dev-menu runs, both of which
    /// have to leave the comparison. See `AptabaseCohortSource`.
    static let cohortSource = "analytics_cohort_source"

    static func decorate(
        _ args: [String: Any],
        transport: AptabaseTransport,
        cohortSource: AptabaseCohortSource,
        sequence sequenceProvider: AnalyticsEventSequence
    ) -> [String: Any] {
        var args = normalized(args)
        args[Self.sequence] = sequenceProvider.next()
        args[Self.transport] = transport.rawValue
        args[Self.installId] = sequenceProvider.installId
        args[Self.cohortSource] = cohortSource.rawValue
        return args
    }

    /// The SDK discards the whole event when a single property is not a scalar.
    /// Flattening the value here fixes them for both transports at once.
    ///
    /// String collections are sorted rather than joined in place. Every list-valued schema field is
    /// `uniqueItems`, so it arrives as a `Set<String>` and crosses `JSONEncoder` on the way here — and
    /// the encoder follows the set's iteration order, which rides on the per-process hash seed. Without
    /// a canonical order the same set of options serialises differently on every launch and nothing
    /// aggregates. Should the schema ever emit a genuinely ordered array, it needs its own branch above
    /// this one instead.
    static func normalized(_ args: [String: Any]) -> [String: Any] {
        args.reduce(into: [:]) { result, element in
            switch element.value {
            case is String, is Bool, is Int, is Double, is Float, is NSNumber:
                result[element.key] = element.value
            case let value as [String]:
                result[element.key] = value.sorted().joined(separator: ",")
            case let value as Set<String>:
                result[element.key] = value.sorted().joined(separator: ",")
            default:
                break
            }
        }
    }
}

final class AnalyticsEventSequence: @unchecked Sendable {
    private static let storageKey = "analytics_event_seq"

    let installId: String

    private let userDefaults: UserDefaults
    private let lock = NSLock()
    private var value: Int

    init(installId: String, userDefaults: UserDefaults = .standard) {
        self.installId = installId
        self.userDefaults = userDefaults
        value = userDefaults.integer(forKey: Self.storageKey)
    }

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        userDefaults.set(value, forKey: Self.storageKey)
        return value
    }
}

class AptabaseService: AnalyticsService {
    private let sequence: AnalyticsEventSequence
    private let cohortSource: AptabaseCohortSource

    init(sequence: AnalyticsEventSequence, cohortSource: AptabaseCohortSource) {
        self.sequence = sequence
        self.cohortSource = cohortSource
    }

    func logEvent(name: String, args: [String: Any]) {
        let props = AptabaseTransportProperty.decorate(
            args,
            transport: .sdk,
            cohortSource: cohortSource,
            sequence: sequence
        )
        DispatchQueue.main.async {
            Aptabase.shared.trackEvent(name, with: props)
        }
    }
}

final class AptabaseQueuedService: AnalyticsService {
    private let client: AptabaseQueueClient
    private let sequence: AnalyticsEventSequence
    private let cohortSource: AptabaseCohortSource
    private let currentDate: @Sendable () -> Date
    private let continuation: AsyncStream<AptabaseQueueInput>.Continuation
    private var lifecycleObservers = [NSObjectProtocol]()

    init(
        client: AptabaseQueueClient,
        sequence: AnalyticsEventSequence,
        cohortSource: AptabaseCohortSource,
        reachabilityTracker: ReachabilityTracker? = nil,
        currentDate: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.sequence = sequence
        self.cohortSource = cohortSource
        self.currentDate = currentDate

        var continuation: AsyncStream<AptabaseQueueInput>.Continuation!
        let inputs = AsyncStream<AptabaseQueueInput>(bufferingPolicy: .unbounded) { continuation = $0 }
        self.continuation = continuation
        observeLifecycle()
        observeReachability(reachabilityTracker)
        Task { await client.start(consuming: inputs) }
    }

    deinit {
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
        continuation.finish()
    }

    func logEvent(name: String, args: [String: Any]) {
        let props = AptabaseTransportProperty.decorate(
            args,
            transport: .cache,
            cohortSource: cohortSource,
            sequence: sequence
        )
        continuation.yield(
            .event(
                AptabasePendingEvent(
                    name: name,
                    props: AptabasePropValue.props(from: props),
                    timestamp: currentDate()
                )
            )
        )
    }
}

extension AptabaseQueuedService: ReachabilityTrackerObserver {
    /// The tracker only reports transitions, so an install that starts online never gets a callback —
    /// `AptabaseQueueClient.start` already flushes what the previous run left behind.
    func didUpdateState(_ state: ReachabilityTracker.State) {
        guard state == .connected else { return }
        continuation.yield(.networkAvailable)
    }
}

private extension AptabaseQueuedService {
    /// The tracker delivers on the main queue and its observer list is not synchronised, so it is
    /// subscribed from there too — `init` runs wherever `CoreAssembly.analyticsProvider` is first touched.
    func observeReachability(_ reachabilityTracker: ReachabilityTracker?) {
        guard let reachabilityTracker else { return }
        DispatchQueue.main.async { [self] in
            reachabilityTracker.addObserver(self)
        }
    }

    func observeLifecycle() {
        let center = NotificationCenter.default
        lifecycleObservers = [
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [continuation] _ in
                continuation.yield(.resumed)
            },
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [continuation] _ in
                MainActor.assumeIsolated {
                    let assertion = AptabaseBackgroundAssertion(name: "AptabaseFlush")
                    continuation.yield(.suspended { assertion.end() })
                }
            },
        ]
    }
}

@MainActor
private final class AptabaseBackgroundAssertion {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    init(name: String) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            MainActor.assumeIsolated { self?.end() }
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
