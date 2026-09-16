import TKLogging

/// Reaction to a rotated device id: the previous device's bindings are gone, so they are rebuilt
/// before the owner of the push subscription is told to resubscribe.
///
/// One reconcile runs at a time. A rotation that lands while one is in flight leaves that reconcile
/// describing the previous device, so it is repeated rather than dropped.
actor MultichainDeviceChangeController {
    /// A reconcile can itself rotate the device — it authenticates, and a rejected session
    /// re-registers — so the repeat is bounded: every pass costs a round trip.
    static let maxReconciles = 3

    private let reconcileBindings: () async -> Void
    private let didChangeDevice: () async -> Void

    private var isHandling = false
    private var hasPendingChange = false

    init(
        reconcileBindings: @escaping () async -> Void,
        didChangeDevice: @escaping () async -> Void
    ) {
        self.reconcileBindings = reconcileBindings
        self.didChangeDevice = didChangeDevice
    }

    func handle() async {
        // Check-and-set with no suspension in between, so a rotation arriving here either starts
        // the loop or is recorded for it — never both, never neither.
        guard !isHandling else {
            hasPendingChange = true
            return
        }
        isHandling = true
        defer { isHandling = false }

        var remainingPasses = Self.maxReconciles
        repeat {
            repeat {
                hasPendingChange = false
                remainingPasses -= 1
                await reconcileBindings()
            } while hasPendingChange && remainingPasses > 0
            // The push subscription keys off the current device id, so one notification after the
            // last pass covers every rotation coalesced into it. It resolves that id by
            // authenticating, so it can rotate the device itself — and `isHandling` is still set
            // while it runs, which turns such a rotation into a pending change nobody would pick
            // up. Both loops share one budget, so the repeat stays bounded.
            await didChangeDevice()
        } while hasPendingChange && remainingPasses > 0

        if hasPendingChange {
            Log.w("🪵 DeviceAuth: bindings still behind the device id after \(Self.maxReconciles) reconciles")
        }
    }
}
