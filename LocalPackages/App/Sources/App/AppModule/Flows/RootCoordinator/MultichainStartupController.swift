import KeeperCore

actor MultichainStartupController {
    private let authService: MultichainAuthService
    private let walletSyncController: MultichainWalletSyncController

    private var didStartPendingUnregisterFlush = false
    private var didReconcileBindings = false
    private var isReconcilingBindings = false
    private var hasPendingReconcile = false

    init(
        authService: MultichainAuthService,
        walletSyncController: MultichainWalletSyncController
    ) {
        self.authService = authService
        self.walletSyncController = walletSyncController
    }

    func startPendingUnregisterFlush() async {
        guard !didStartPendingUnregisterFlush else { return }
        didStartPendingUnregisterFlush = true
        await authService.flushPendingUnregisters()
    }

    /// Silent counterpart of the passcode-gated sync: it only marks unbound wallets for the next
    /// sync. Running it once after startup sync prevents it from reverting a newly bound wallet —
    /// but a pass that never reached the backend has bound nothing, so it is repeated on the next
    /// trigger instead of leaving the device without bindings for the whole run.
    func startBindingsReconcile() async {
        guard !didReconcileBindings else { return }
        // A trigger that arrives mid-pass is not redundant: the pass in flight can still fail, and
        // dropping the trigger would leave the device without bindings until the next foreground.
        guard !isReconcilingBindings else {
            hasPendingReconcile = true
            return
        }
        isReconcilingBindings = true
        defer { isReconcilingBindings = false }
        repeat {
            hasPendingReconcile = false
            didReconcileBindings = await walletSyncController.reconcileBindings()
        } while !didReconcileBindings && hasPendingReconcile
    }
}
