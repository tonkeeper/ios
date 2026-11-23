import Foundation
import TKAppInfo
import UIKit

package enum AptabaseConfigurator {
    static func usableEndpoint(_ endpoint: String?) -> String? {
        guard let endpoint,
              let url = URL(string: endpoint),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty
        else { return nil }
        return endpoint
    }

    /// `nil` when the app bundle carries no Aptabase configuration.
    package static func makeAnalyticsService(
        installId: String,
        sendStatsImmediately: Bool?,
        reachabilityTracker: ReachabilityTracker,
        remoteEndpoint: @escaping @Sendable () -> String?
    ) -> AnalyticsService? {
        guard let bundledEndpoint = InfoProvider.aptabaseEndpoint(),
              let appKey = InfoProvider.aptabaseKey()
        else { return nil }

        var environment = AptabaseEnvironment.current()
        if let sendStatsImmediately {
            environment.isDebug = sendStatsImmediately
        }

        let client = AptabaseQueueClient(
            store: AptabaseEventStore(configuration: .default()),
            dispatcher: AptabaseDispatcher(
                endpointProvider: { usableEndpoint(remoteEndpoint()) ?? bundledEndpoint },
                appKey: appKey,
                environment: environment,
                session: URLSession.shared
            ),
            environment: environment,
            flushInterval: environment.isDebug ? 2 : 60
        )
        return AptabaseQueuedService(
            client: client,
            sequence: AnalyticsEventSequence(installId: installId),
            reachabilityTracker: reachabilityTracker
        )
    }
}

enum AptabaseTransportProperty {
    /// Monotonic per-install counter; gaps in it are lost events.
    static let sequence = "event_seq"
    static let transport = "analytics_transport"
    /// Scopes `event_seq`, which restarts from zero after a reinstall while `firebase_user_id` lives in
    /// the keychain and survives one — grouping by that alone would splice two overlapping ranges into
    /// a single install and let values from one install mask gaps in the other.
    static let installId = "analytics_install_id"

    private static let cacheTransport = "cache"

    static func decorate(
        _ args: [String: Any],
        sequence sequenceProvider: AnalyticsEventSequence
    ) -> [String: Any] {
        var args = normalized(args)
        args[Self.sequence] = sequenceProvider.next()
        args[Self.transport] = cacheTransport
        args[Self.installId] = sequenceProvider.installId
        return args
    }

    /// A property that is not a scalar cannot be encoded and would cost the whole event; flattening
    /// it here keeps the event.
    ///
    /// String collections are sorted rather than joined in place. A `uniqueItems` schema field arrives
    /// as a `Set<String>` and crosses `JSONEncoder` on the way here, and the encoder follows the set's
    /// iteration order, which rides on the per-process hash seed. A plain array (`launch_app.widgets`)
    /// keeps its duplicates, but its order carries no meaning either. Without a canonical order the
    /// same values serialise differently on every launch and nothing aggregates. Should the schema ever
    /// emit a genuinely ordered array, it needs its own branch above these instead.
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

final class AptabaseQueuedService: AnalyticsService {
    private let client: AptabaseQueueClient
    private let sequence: AnalyticsEventSequence
    private let currentDate: @Sendable () -> Date
    private let continuation: AsyncStream<AptabaseQueueInput>.Continuation
    private var lifecycleObservers = [NSObjectProtocol]()

    init(
        client: AptabaseQueueClient,
        sequence: AnalyticsEventSequence,
        reachabilityTracker: ReachabilityTracker? = nil,
        currentDate: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.sequence = sequence
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
        let props = AptabaseTransportProperty.decorate(args, sequence: sequence)
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
