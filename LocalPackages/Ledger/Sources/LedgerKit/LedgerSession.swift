import Foundation

/// One Ledger connection kept across app switches: opening or quitting a device app may drop the
/// link, and a dropped link is reconnected before the work goes on.
public actor LedgerSession {
    public enum Phase: Equatable, Sendable {
        case connecting
        /// The link is up and no app has been asked for on it yet.
        case connected
        case openingApp(LedgerApp)
        case running(LedgerApp)
        /// The device would not open the app: it is not installed, or the user refused to open it.
        case notOpened(LedgerApp, isMissing: Bool)
    }

    struct Timing: Sendable {
        var now: @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
        var sleep: @Sendable (TimeInterval) async throws -> Void = {
            try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000))
        }

        static var live: Timing {
            if #available(iOS 16, macOS 13, *) {
                let clock = SuspendingClock()
                let origin = clock.now
                return Timing(now: {
                    let elapsed = origin.duration(to: clock.now).components
                    return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1_000_000_000_000_000_000
                }, sleep: {
                    try await clock.sleep(for: .seconds($0))
                })
            }
            // iOS 15's Task.sleep uses Dispatch uptime, which also stops during system sleep.
            return Timing()
        }
    }

    private let transport: LedgerTransport
    private let peripheralID: UUID
    private let report: @Sendable (Phase) -> Void
    private let pollInterval: TimeInterval
    private let reconnectTimeout: TimeInterval
    private let timing: Timing
    private var link: LedgerLink?

    /// Each call budgets connection attempts (including iOS pairing), retry delays and transient controller states.
    /// Waiting while Bluetooth is `.poweredOff` or `.unauthorized` is excluded, as is waiting for the user
    /// to unlock, open an app or sign on an already connected Ledger.
    public init(
        transport: LedgerTransport,
        peripheralID: UUID,
        pollInterval: TimeInterval = 1,
        reconnectTimeout: TimeInterval = 25,
        report: @escaping @Sendable (Phase) -> Void
    ) {
        self.init(
            transport: transport,
            peripheralID: peripheralID,
            pollInterval: pollInterval,
            reconnectTimeout: reconnectTimeout,
            timing: .live,
            report: report
        )
    }

    init(
        transport: LedgerTransport,
        peripheralID: UUID,
        pollInterval: TimeInterval = 1,
        reconnectTimeout: TimeInterval = 25,
        timing: Timing,
        report: @escaping @Sendable (Phase) -> Void
    ) {
        self.transport = transport
        self.peripheralID = peripheralID
        self.pollInterval = pollInterval
        self.reconnectTimeout = reconnectTimeout
        self.timing = timing
        self.report = report
    }

    /// Reconnects while opening `app`. Only reads that can safely restart should opt into `retryBody`;
    /// signing bodies are not replayed after a link loss.
    public func run<T: Sendable>(on app: LedgerApp, retryBody: Bool = false, _ body: @Sendable (LedgerLink) async throws -> T) async throws -> T {
        var hasStartedBody = false
        return try await recovering(shouldRetry: { !hasStartedBody || retryBody }) { link in
            while true {
                try Task.checkCancellation()
                report(.openingApp(app))
                let version: String?
                do {
                    version = try await link.open(app)
                } catch let error as LedgerStatusError where error.isAppMissing || error.isRefused {
                    report(.notOpened(app, isMissing: error.isAppMissing))
                    throw error
                }
                guard version != nil else {
                    try await timing.sleep(pollInterval)
                    continue
                }
                report(.running(app))
                hasStartedBody = true
                return try await body(link)
            }
        }
    }

    /// Connects ahead of the first app, so that the link is up while the user still decides on the apps.
    public func connect() async throws {
        try await recovering { _ in () }
    }

    public func close() {
        link?.close()
        link = nil
    }

    private func recovering<T: Sendable>(shouldRetry: () -> Bool = { true }, _ body: (LedgerLink) async throws -> T) async throws -> T {
        var remaining = reconnectTimeout
        do {
            while true {
                try Task.checkCancellation()
                do {
                    if link == nil {
                        guard remaining > 0 else {
                            throw LedgerTransportError.timeout
                        }
                        let started = timing.now()
                        defer { remaining -= max(0, timing.now() - started) }
                        report(.connecting)
                        link = try await connect(within: remaining)
                        try Task.checkCancellation()
                        report(.connected)
                    }
                    guard let link else {
                        throw LedgerTransportError.disconnected
                    }
                    let value = try await body(link)
                    try Task.checkCancellation()
                    return value
                } catch let error as LedgerTransportError where error.isLinkLost {
                    close()
                    try Task.checkCancellation()
                    guard shouldRetry() else {
                        throw error
                    }
                    if case .bluetoothUnavailable = error {
                        try await waitForBluetooth()
                    }
                    guard remaining > 0 else {
                        throw LedgerTransportError.timeout
                    }
                    let started = timing.now()
                    defer { remaining -= max(0, timing.now() - started) }
                    try await timing.sleep(min(pollInterval, remaining))
                }
            }
        } catch is CancellationError {
            // A run stopped midway may leave its link in the middle of an exchange; the next run connects again.
            close()
            throw CancellationError()
        }
    }

    private func waitForBluetooth() async throws {
        report(.connecting)
        for await state in transport.bluetoothState() {
            try Task.checkCancellation()
            switch state {
            case .poweredOff, .unauthorized:
                continue
            case .poweredOn, .unknown, .resetting:
                // Controller transitions use the bounded retry loop rather than waiting for user action.
                return
            case .unsupported:
                throw LedgerTransportError.bluetoothUnsupported
            @unknown default:
                throw LedgerTransportError.bluetoothUnsupported
            }
        }
        try Task.checkCancellation()
        throw LedgerTransportError.bluetoothUnavailable
    }

    private func connect(within timeout: TimeInterval) async throws -> LedgerLink {
        let transport = transport
        let peripheralID = peripheralID
        let timing = timing
        return try await withThrowingTaskGroup(of: LedgerLink.self) { group in
            group.addTask {
                let link = try await transport.connect(peripheralID)
                do {
                    try Task.checkCancellation()
                } catch {
                    link.close()
                    throw error
                }
                return link
            }
            group.addTask {
                try await timing.sleep(timeout)
                try Task.checkCancellation()
                throw LedgerTransportError.timeout
            }
            defer { group.cancelAll() }
            do {
                guard let link = try await group.next() else {
                    throw LedgerTransportError.disconnected
                }
                return link
            } catch {
                group.cancelAll()
                while let result = await group.nextResult() {
                    if case let .success(link) = result {
                        link.close()
                    }
                }
                throw error
            }
        }
    }
}

private extension LedgerTransportError {
    var isLinkLost: Bool {
        switch self {
        case .disconnected, .timeout, .peripheralNotFound, .bluetoothUnavailable:
            true
        case .bluetoothUnsupported, .pairingRemoved, .busy, .invalidRequest, .invalidResponse:
            false
        }
    }
}
