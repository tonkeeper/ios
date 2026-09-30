import KeeperCore
import TKCore
import TKLogging
import TKUIKit
import TonSwift
import UIKit
import UserNotifications

final class PushNotificationManager {
    private let queue = DispatchQueue(label: "PushNotificationManagerQueue", qos: .userInitiated)
    private var notificationsUpdateTask = [Wallet: Task<Void, Never>]()
    /// v1 mutates one wallet at a time and has no confirmed-state cache, so its requests need a
    /// tail per wallet — see `SerialRequestQueue`.
    private let legacySyncQueue = SerialRequestQueue<String>()
    /// Wallets whose next store event is this manager writing a rejected toggle back, not the user
    /// asking for anything: reacting to it would send the opposite request.
    private var revertingWallets = Set<Wallet>()
    /// Wallets whose next store event is this manager enabling notifications on its own after an
    /// add, not the user asking for anything: a failure there must not flip the preference back or
    /// raise a toast — the next reconcile retries it.
    private var autoEnabledWallets = Set<String>()
    /// Owns the v2 contour end to end (serialization, generation, cache key); like the rest of the
    /// manager's mutable state it is only reached from `queue`.
    private lazy var multichainPush = makeMultichainPushSynchronizer()
    private var legacyCleanupTask: Task<Void, Never>?
    private var legacyCleanupGeneration = 0

    private let appSettings: AppSettings
    private let uniqueIdProvider: UniqueIdProvider
    private let pushNotificationTokenProvider: PushNotificationTokenProvider
    private let pushNotificationAPI: PushNotificationsAPI
    private let walletNotificationsStore: WalletNotificationStore
    private let walletsStore: WalletsStore
    private let tonConnectAppsStore: TonConnectAppsStore
    private let tonProofTokenService: TonProofTokenService
    private let multichainAuthService: MultichainAuthService

    init(
        appSettings: AppSettings,
        uniqueIdProvider: UniqueIdProvider,
        pushNotificationTokenProvider: PushNotificationTokenProvider,
        pushNotificationAPI: PushNotificationsAPI,
        walletNotificationsStore: WalletNotificationStore,
        walletsStore: WalletsStore,
        tonConnectAppsStore: TonConnectAppsStore,
        tonProofTokenService: TonProofTokenService,
        multichainAuthService: MultichainAuthService
    ) {
        self.appSettings = appSettings
        self.uniqueIdProvider = uniqueIdProvider
        self.pushNotificationTokenProvider = pushNotificationTokenProvider
        self.pushNotificationAPI = pushNotificationAPI
        self.walletNotificationsStore = walletNotificationsStore
        self.walletsStore = walletsStore
        self.tonConnectAppsStore = tonConnectAppsStore
        self.tonProofTokenService = tonProofTokenService
        self.multichainAuthService = multichainAuthService
    }

    deinit {
        legacyCleanupTask?.cancel()
        notificationsUpdateTask.values.forEach { $0.cancel() }
    }

    func setup() {
        pushNotificationTokenProvider.setup()
        walletNotificationsStore.addObserver(self) { observer, event in
            observer.queue.async {
                observer.didGetNotificationsStoreEvent(event)
            }
        }
        walletsStore.addObserver(self) { observer, event in
            observer.queue.async {
                observer.didGetWalletsStoreEvent(event)
            }
        }

        pushNotificationTokenProvider.didUpdateToken = { [weak self] token in
            self?.queue.async {
                self?.didUpdateToken(token)
            }
        }
        Task {
            await registerForPushNotificationsIfNeeded()
        }
    }

    /// Re-run subscribe for wallets that already have notifications enabled.
    /// Call after wallets are registered with the backend so earlier no-op subscribes are retried.
    func refreshSubscriptions() {
        queue.async { [weak self] in
            guard let self else { return }
            if let token = self.appSettings.fcmToken {
                self.reconcilePushSubscriptions(token: token)
                return
            }
            // v2 authenticates with the device JWT and drops the whole set without a push token,
            // so an unresolvable token must not leave the old subscription behind. Only the v1
            // subscribes have to wait for it.
            self.scheduleMultichainSync(requireAuthorization: false)
            Task { [weak self] in
                guard let self else { return }
                guard let token = await self.pushNotificationTokenProvider.getToken() else {
                    Log.w("🪵 Push: refreshSubscriptions skipped — no FCM token")
                    return
                }
                self.queue.sync {
                    self.reconcilePushSubscriptions(token: token)
                }
            }
        }
    }

    private func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
        if case let .didAddWallets(wallets) = event {
            autoEnableNotificationsIfPermitted(for: wallets)
        }
        guard affectsMultichainPushSet(event) else { return }
        scheduleMultichainSync(requireAuthorization: false)
    }

    /// A wallet added while push permission is already granted starts subscribed: the grant is the
    /// preference, and Settings is where it gets turned back off. Permission the user has not given
    /// is not asked for here — the wallet stays unsubscribed until they enable it themselves.
    private func autoEnableNotificationsIfPermitted(for wallets: [Wallet]) {
        Task { [weak self] in
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            guard status.isPushAuthorized else { return }
            self?.autoEnableNotifications(for: wallets)
        }
    }

    private func autoEnableNotifications(for wallets: [Wallet]) {
        queue.async { [weak self] in
            guard let self else { return }
            let notificationState = self.walletNotificationsStore.getState()
            for wallet in wallets {
                guard let current = self.walletsStore.getWallet(id: wallet.id),
                      !(notificationState[current]?.isOn ?? false)
                else {
                    continue
                }
                self.autoEnabledWallets.insert(current.id)
                self.walletNotificationsStore.setNotificationIsOn(true, wallet: current, completion: nil)
            }
        }
    }

    /// A failed or deferred v2 sync leaves v1 in place; the next sync retries the handoff.
    private func scheduleLegacyCleanupAfterSettlement() {
        let synchronizer = multichainPush
        legacyCleanupGeneration += 1
        let generation = legacyCleanupGeneration
        legacyCleanupTask?.cancel()
        legacyCleanupTask = Task { [weak self] in
            guard case .settled = await synchronizer.settledOutcome(), !Task.isCancelled else { return }
            self?.cleanupLegacyPushAfterSettlement(generation: generation)
        }
    }

    private func cleanupLegacyPushAfterSettlement(generation: Int) {
        queue.async { [weak self] in
            guard let self, generation == self.legacyCleanupGeneration else { return }
            let notificationState = self.walletNotificationsStore.getState()
            let confirmedWalletIds = Set(self.appSettings.multichainPushWalletIds ?? [])
            let wallets = self.walletsStore.wallets.filter { wallet in
                wallet.needsLegacyPushCleanup(
                    isNotificationsOn: notificationState[wallet]?.isOn ?? false,
                    confirmedMultichainPushWalletIds: confirmedWalletIds
                )
            }
            self.cleanupLegacyPush(for: wallets)
        }
    }

    /// Uses the wallet's v1 tail so cleanup cannot overtake an earlier subscribe.
    private func cleanupLegacyPush(for wallets: [Wallet]) {
        for wallet in wallets {
            legacySyncQueue.enqueue(wallet.id) { [weak self] in
                _ = await self?.performUnsubscribe(wallet: wallet)
            }
        }
    }

    /// Only bound wallets may be in the v2 set, so a binding that just landed — or a deletion that
    /// takes one out — has to invalidate the last synced set instead of waiting for the next toggle.
    private func affectsMultichainPushSet(_ event: WalletsStore.Event) -> Bool {
        switch event {
        case .didUpdateWalletMultichain, .didDeleteAll:
            return true
        case let .didDeleteWallet(wallet):
            return wallet.boundMultichainPushWalletId != nil
        default:
            return false
        }
    }

    /// A permission already in hand is never re-requested here: a provisional one would answer
    /// with the full-authorization prompt, and launch is not where that belongs.
    private func registerForPushNotificationsIfNeeded() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard status.isPushAuthorized else { return }
        await UIApplication.shared.registerForRemoteNotifications()
    }

    private func registerForPushNotifications() async {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        do {
            guard try await UNUserNotificationCenter.current().requestAuthorization(options: authOptions) else {
                return
            }
            await UIApplication.shared.registerForRemoteNotifications()
        } catch {
            Log.w("Log 🪵: PushNotificationManager - failed to register for remote notifications")
        }
    }

    private func didGetNotificationsStoreEvent(_ event: WalletNotificationStore.Event) {
        switch event {
        case let .didUpdateNotificationsIsOn(wallet):
            guard revertingWallets.remove(wallet) == nil else { return }
            let isOn = walletNotificationsStore.getState()[wallet]?.isOn ?? false
            let isUserIntent = autoEnabledWallets.remove(wallet.id) == nil
            guard !usesMultichainPush(wallet) else {
                if !isOn {
                    // Turning off has to silence a leftover v1 subscription whatever v2 answers,
                    // so it does not wait for the settlement cleanup. A revert that puts the
                    // toggle back leaves the wallet on v2 alone — the only contour that may own
                    // it — and `compensateRevert` schedules the pass that subscribes it there.
                    let current = walletsStore.getWallet(id: wallet.id) ?? wallet
                    cleanupLegacyPush(for: [current])
                }
                applyMultichainIntent(wallet: wallet, isOn: isOn, revertsOnFailure: isUserIntent)
                return
            }
            enqueueLegacySync(wallet: wallet, revertsOnFailure: isUserIntent)
        case .didUpdateDappNotificationsIsOn:
            break
        }
    }

    /// v2 takes the whole set, so a single toggle is still a full resync — and the toggle stays
    /// where the user put it only if that resync reached the backend. A wallet whose binding has
    /// not landed yet is not a rejection: it enters the set once it is bound, and
    /// `refreshSubscriptions()` replays it then.
    private func applyMultichainIntent(wallet: Wallet, isOn: Bool, revertsOnFailure: Bool) {
        guard scheduleMultichainSync(requireAuthorization: isOn) != nil else { return }
        notificationsUpdateTask[wallet]?.cancel()
        notificationsUpdateTask[wallet] = nil
        guard revertsOnFailure else { return }
        let synchronizer = multichainPush
        notificationsUpdateTask[wallet] = Task { [weak self] in
            // A toggle on another wallet — or a background reconcile — supersedes this pass and
            // carries its change instead, so the verdict belongs to whichever pass ran last.
            let outcome = await synchronizer.settledOutcome()
            guard case .failed = outcome, !Task.isCancelled else { return }
            self?.revertMultichainIntentIfNeeded(wallet: wallet, isOn: isOn)
        }
    }

    private func revertMultichainIntentIfNeeded(wallet: Wallet, isOn: Bool) {
        queue.async { [weak self] in
            guard let self, !self.didMultichainIntentLand(wallet: wallet, isOn: isOn) else { return }
            self.performRevert(wallet: wallet, to: !isOn, isMultichain: true)
        }
    }

    /// The failed pass is not necessarily this wallet's: the set is shared, so a later pass can fail
    /// over a change this one had already delivered. Only the last confirmed set can tell them
    /// apart. A wallet with no binding yet is never in that set and is not a rejection — it joins
    /// once the binding lands.
    private func didMultichainIntentLand(wallet: Wallet, isOn: Bool) -> Bool {
        guard let walletId = walletsStore.wallets
            .first(where: { $0.id == wallet.id })?
            .boundMultichainPushWalletId
        else {
            return true
        }
        return (appSettings.multichainPushWalletIds ?? []).contains(walletId) == isOn
    }

    /// The store is written before the request goes out, so a rejected toggle has to be put back —
    /// otherwise the user is looking at a subscription that does not exist.
    private func revertNotificationsIsOn(wallet: Wallet, to isOn: Bool) {
        queue.async { [weak self] in
            self?.performRevert(wallet: wallet, to: isOn, isMultichain: false)
        }
    }

    private func performRevert(wallet: Wallet, to isOn: Bool, isMultichain: Bool) {
        // Turning notifications off is also what a delete and a sign-out do first, and a wallet
        // that is already gone has no preference left to restore or to report on.
        guard walletsStore.wallets.contains(where: { $0.id == wallet.id }) else { return }
        revertingWallets.insert(wallet)
        walletNotificationsStore.setNotificationIsOn(isOn, wallet: wallet) { [weak self] _ in
            self?.queue.async { [weak self] in
                self?.compensateRevert(wallet: wallet, isMultichain: isMultichain)
            }
        }
        Task { @MainActor in
            ToastPresenter.showToast(configuration: .failed)
        }
    }

    /// A request that failed after it left the device may still have been applied, so the reverted
    /// preference has to be pushed once more. The compensating pass carries no verdict of its own:
    /// the toggle has already been reported, and a second toast would be noise. The revert itself
    /// is suppressed as a store event, so it cannot schedule this pass on its own.
    private func compensateRevert(wallet: Wallet, isMultichain: Bool) {
        guard isMultichain else {
            // v1 keeps no confirmed state to invalidate, so the correction is another pass over the
            // wallet's tail. It reads the preference when it starts, so a toggle the user made
            // after the revert supersedes it rather than racing it.
            enqueueLegacySync(wallet: wallet)
            return
        }
        scheduleMultichainSync(requireAuthorization: false)
    }

    private func didUpdateToken(_ token: String?) {
        appSettings.fcmToken = token
        guard let token else { return }
        reconcilePushSubscriptions(token: token)
    }

    private func reconcilePushSubscriptions(token: String) {
        let state = walletNotificationsStore.getState()
        let enabledWallets = state.filter { $0.value.isOn }.map { $0.key }

        scheduleMultichainSync(token: token, requireAuthorization: false)

        for wallet in enabledWallets where !usesMultichainPush(wallet) {
            enqueueLegacySync(wallet: wallet, token: token)
        }
    }

    @discardableResult
    private func scheduleMultichainSync(
        token: String? = nil,
        requireAuthorization: Bool
    ) -> Task<MultichainPushSynchronizer.Outcome, Never>? {
        guard let task = multichainPush.schedule(token: token, requireAuthorization: requireAuthorization) else {
            return nil
        }
        scheduleLegacyCleanupAfterSettlement()
        return task
    }

    private func makeMultichainPushSynchronizer() -> MultichainPushSynchronizer {
        MultichainPushSynchronizer(
            dependencies: MultichainPushSynchronizerDependencies(
                desiredWalletIds: { [weak self] in self?.multichainEnabledWalletIds() ?? [] },
                loadState: { [appSettings] in
                    MultichainPushSyncState(
                        walletIds: appSettings.multichainPushWalletIds,
                        token: appSettings.multichainPushToken,
                        deviceId: appSettings.multichainPushDeviceId
                    )
                },
                saveState: { [appSettings] state in
                    appSettings.multichainPushToken = state.token
                    appSettings.multichainPushWalletIds = state.walletIds
                    appSettings.multichainPushDeviceId = state.deviceId
                },
                deviceId: { [multichainAuthService] in
                    try await multichainAuthService.deviceId()
                },
                resolveToken: { [weak self] hint in
                    await self?.resolveToken(hint)
                },
                requestAuthorization: { [weak self] in
                    await self?.ensureRegistered()
                },
                subscribe: { [multichainAuthService] pushToken, walletIds in
                    try await multichainAuthService.subscribePush(
                        pushToken: pushToken,
                        locale: Locale.current.languageCode ?? "en",
                        walletIds: walletIds
                    )
                },
                unsubscribe: { [multichainAuthService] in
                    try await multichainAuthService.unsubscribePush()
                }
            )
        )
    }

    /// The notification store's wallet snapshots go stale as bindings land, so the ids come from
    /// the wallets store. Only bound wallets may be in the set: the backend silently ignores ids
    /// the device is not bound to, and caching them would look like a successful subscribe.
    private func multichainEnabledWalletIds() -> [String] {
        let notified = Set(
            walletNotificationsStore.getState()
                .filter { $0.value.isOn }
                .map { $0.key.id }
        )
        let ids = walletsStore.wallets
            .filter { notified.contains($0.id) }
            .compactMap(\.boundMultichainPushWalletId)
        return Array(Set(ids)).sorted()
    }

    private func usesMultichainPush(_ wallet: Wallet) -> Bool {
        let current = walletsStore.getWallet(id: wallet.id) ?? wallet
        return current.usesMultichainPush()
    }

    /// Every v1 mutation of a wallet goes through its own serial tail, so a correction and a fresh
    /// toggle can never be in flight together. `revertsOnFailure` is the user's own toggle: a
    /// background reconcile must never turn the user's preference off just because the network
    /// was down.
    private func enqueueLegacySync(
        wallet: Wallet,
        token: String? = nil,
        revertsOnFailure: Bool = false
    ) {
        legacySyncQueue.enqueue(wallet.id) { [weak self] in
            await self?.runLegacySync(wallet: wallet, token: token, revertsOnFailure: revertsOnFailure)
        }
    }

    /// The preference is read when the pass starts, not when it was queued: by then an earlier
    /// request has finished and the user may have moved the toggle again.
    private func runLegacySync(wallet: Wallet, token: String?, revertsOnFailure: Bool) async {
        let isOn = walletNotificationsStore.getState()[wallet]?.isOn ?? false
        guard isOn else {
            let didUnsubscribe = await performUnsubscribe(wallet: wallet)
            guard !didUnsubscribe, revertsOnFailure else { return }
            revertNotificationsIsOn(wallet: wallet, to: true)
            return
        }
        await ensureRegistered()
        // A missing token is a wait, not a rejection: its arrival reconciles the subscriptions.
        guard let resolvedToken = await resolveToken(token) else {
            Log.w("🪵 Push: subscribe deferred — FCM token unavailable for wallet=\(wallet.id)")
            return
        }
        let didSubscribe = await performSubscribe(wallet: wallet, token: resolvedToken)
        guard !didSubscribe, revertsOnFailure else { return }
        revertNotificationsIsOn(wallet: wallet, to: false)
    }

    private func ensureRegistered() async {
        let isAuthorized = await UNUserNotificationCenter.current()
            .notificationSettings()
            .authorizationStatus
            .isPushAuthorized

        if isAuthorized {
            // A grant that happened after launch (onboarding, Settings) leaves the app without an
            // APNs token until the next cold start, and FCM cannot deliver without one.
            await UIApplication.shared.registerForRemoteNotifications()
        } else {
            await registerForPushNotifications()
        }
    }

    private func resolveToken(_ token: String?) async -> String? {
        if let token {
            return token
        }
        return await pushNotificationTokenProvider.getToken()
    }

    /// `false` covers both a thrown error and an `ok: false` body — neither leaves a subscription
    /// behind, so the caller must not treat them differently.
    private func performSubscribe(wallet: Wallet, token: String) async -> Bool {
        let device = uniqueIdProvider.uniqueDeviceId.uuidString
        let locale = Locale.current.languageCode ?? "en"
        do {
            return try await pushNotificationAPI.subscribeNotifications(
                subscribeData: PushNotificationsAPI.SubscribeData(
                    token: token,
                    device: device,
                    accounts: [PushNotificationsAPI.SubscribeData.Account(address: wallet.friendlyAddress.toString())],
                    locale: locale
                )
            )
        } catch {
            Log.w("🪵 Push: subscribe failed for wallet=\(wallet.id)", error: error)
            return false
        }
    }

    /// v1 `/unsubscribe` is keyed by device and TON address only, so it needs no push token and
    /// never has to be deferred until one arrives.
    private func performUnsubscribe(wallet: Wallet) async -> Bool {
        let device = uniqueIdProvider.uniqueDeviceId.uuidString
        do {
            return try await pushNotificationAPI.unsubscribeNotifications(
                unsubscribeData: PushNotificationsAPI.UnsubscribeData(
                    device: device,
                    accounts: [PushNotificationsAPI.UnsubscribeData.Account(address: wallet.friendlyAddress.toString())]
                )
            )
        } catch {
            Log.w("🪵 Push: unsubscribe failed for wallet=\(wallet.id)", error: error)
            return false
        }
    }
}

extension Wallet {
    /// Push v2 owns every multichain wallet, bound or not: v1 keys on the TON address and would
    /// double-subscribe the same wallet once the binding lands.
    func usesMultichainPush() -> Bool {
        guard kind == .regular, case .multichain = multichain else {
            return false
        }
        return true
    }

    func needsLegacyPushCleanup(
        isNotificationsOn: Bool,
        confirmedMultichainPushWalletIds: Set<String>
    ) -> Bool {
        guard usesMultichainPush() else { return false }
        guard isNotificationsOn else { return true }
        guard let walletId = boundMultichainPushWalletId else { return false }
        return confirmedMultichainPushWalletIds.contains(walletId)
    }
}

private extension Wallet {
    var boundMultichainPushWalletId: String? {
        guard kind == .regular,
              case let .multichain(state) = multichain,
              state.syncState == .synced
        else {
            return nil
        }
        return state.walletId
    }
}
