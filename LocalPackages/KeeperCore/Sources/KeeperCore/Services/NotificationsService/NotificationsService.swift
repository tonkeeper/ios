import Foundation

/// dApp toggles set `commercial`, wallet toggles set `silent`; only disconnect removes a subscription.
/// Each connected session receives its own update.
public protocol NotificationsService {
    /// `previousIsOn` restores sessions already updated when a later session fails.
    func setDappNotifications(
        isOn: Bool,
        previousIsOn: Bool,
        wallet: Wallet,
        manifest: TonConnectManifest,
        token: String
    ) async throws -> Bool
    /// Re-sends connected sessions after wallet, token or session changes; optionally filters by host.
    func syncDappNotifications(wallet: Wallet, host: String?, token: String) async -> Bool
    func unsubscribeDappNotifications(
        wallet: Wallet,
        manifest: TonConnectManifest,
        token: String
    ) async throws -> Bool
}

final class NotificationsServiceImplementation: NotificationsService {
    private static let requests = WalletRequests()

    private let pushNotificationAPI: PushNotificationsAPI
    private let walletNotificationsStore: WalletNotificationStore
    private let tonConnectAppsStore: TonConnectAppsStore
    private let tonProofTokenService: TonProofTokenService

    init(
        pushNotificationAPI: PushNotificationsAPI,
        walletNotificationsStore: WalletNotificationStore,
        tonConnectAppsStore: TonConnectAppsStore,
        tonProofTokenService: TonProofTokenService
    ) {
        self.pushNotificationAPI = pushNotificationAPI
        self.walletNotificationsStore = walletNotificationsStore
        self.tonConnectAppsStore = tonConnectAppsStore
        self.tonProofTokenService = tonProofTokenService
    }

    func setDappNotifications(
        isOn: Bool,
        previousIsOn: Bool,
        wallet: Wallet,
        manifest: TonConnectManifest,
        token: String
    ) async throws -> Bool {
        try await Self.requests.run(wallet.id) { [self] in
            let isWalletOn = walletNotificationsStore.getState()[wallet]?.isOn ?? false
            let sessionIds = try connectedApps(wallet: wallet)
                .filter { $0.manifest.host == manifest.host }
                .map(\.clientId)
            guard !sessionIds.isEmpty else { return true }
            return try await subscribe(
                manifest: manifest,
                token: token,
                account: wallet.address.toRaw(),
                tonProof: tonProofTokenService.getWalletToken(wallet),
                commercial: isOn,
                silent: !isWalletOn,
                rollbackCommercial: previousIsOn,
                sessionIds: sessionIds
            )
        }
    }

    func syncDappNotifications(wallet: Wallet, host: String?, token: String) async -> Bool {
        (try? await Self.requests.run(wallet.id) { [self] in
            let state = walletNotificationsStore.getState()[wallet]
            let isWalletOn = state?.isOn ?? false
            let apps = try connectedApps(wallet: wallet).filter { host == nil || $0.manifest.host == host }
            guard !apps.isEmpty else { return true }
            let account = try wallet.address.toRaw()
            let tonProof = try tonProofTokenService.getWalletToken(wallet)
            let appsByHost = Dictionary(grouping: apps, by: { $0.manifest.host })
            var isSynced = true
            for (host, sessions) in appsByHost {
                guard let manifest = sessions.first?.manifest else { continue }
                let didSync = (try? await subscribe(
                    manifest: manifest,
                    token: token,
                    account: account,
                    tonProof: tonProof,
                    commercial: state?.dapps[host] ?? false,
                    silent: !isWalletOn,
                    sessionIds: sessions.map(\.clientId)
                )) ?? false
                isSynced = isSynced && didSync
            }
            return isSynced
        }) ?? false
    }

    func unsubscribeDappNotifications(
        wallet: Wallet,
        manifest: TonConnectManifest,
        token: String
    ) async throws -> Bool {
        try await Self.requests.run(wallet.id) { [self] in
            let data = try PushNotificationsAPI.DappUnsubscribeData(
                token: token,
                appURL: manifest.url.absoluteString,
                account: wallet.address.toRaw(),
                tonProof: tonProofTokenService.getWalletToken(wallet)
            )
            return try await pushNotificationAPI.unsubscribeDappNotifications(unsubscribeData: data)
        }
    }

    private func subscribe(
        manifest: TonConnectManifest,
        token: String,
        account: String,
        tonProof: String,
        commercial: Bool,
        silent: Bool,
        rollbackCommercial: Bool? = nil,
        sessionIds: [String]
    ) async throws -> Bool {
        func send(_ sessionId: String, commercial: Bool) async throws -> Bool {
            let data = PushNotificationsAPI.DappSubscribeData(
                token: token,
                appURL: manifest.url.absoluteString,
                account: account,
                tonProof: tonProof,
                sessionId: sessionId,
                commercial: commercial,
                silent: silent
            )
            return try await pushNotificationAPI.subscribeDappNotifications(subscribeData: data)
        }
        return try await Self.sendSessionUpdates(
            sessionIds,
            commercial: commercial,
            rollbackCommercial: rollbackCommercial,
            send: send
        )
    }

    static func sendSessionUpdates(
        _ sessionIds: [String],
        commercial: Bool,
        rollbackCommercial: Bool?,
        send: (String, Bool) async throws -> Bool
    ) async throws -> Bool {
        for sessionId in sessionIds {
            do {
                guard try await send(sessionId, commercial) else {
                    if let rollbackCommercial {
                        await restore(sessionIds, commercial: rollbackCommercial, send: send)
                    }
                    return false
                }
            } catch {
                if let rollbackCommercial {
                    await restore(sessionIds, commercial: rollbackCommercial, send: send)
                }
                throw error
            }
        }
        return true
    }

    private static func restore(
        _ sessionIds: [String],
        commercial: Bool,
        send: (String, Bool) async throws -> Bool
    ) async {
        for sessionId in sessionIds {
            _ = try? await send(sessionId, commercial)
        }
    }

    private func connectedApps(wallet: Wallet) throws -> [TonConnectApp] {
        try tonConnectAppsStore.connectedApps(forWallet: wallet).apps
    }
}

actor WalletRequests {
    private var active = Set<String>()
    private var waiting = [String: [CheckedContinuation<Void, Never>]]()

    func run(_ key: String, _ operation: () async throws -> Bool) async rethrows -> Bool {
        if active.contains(key) {
            await withCheckedContinuation { waiting[key, default: []].append($0) }
        } else {
            active.insert(key)
        }
        defer { release(key) }
        return try await operation()
    }

    func hasWaitingRequest(for key: String) -> Bool {
        waiting[key]?.isEmpty == false
    }

    private func release(_ key: String) {
        if var queued = waiting[key], !queued.isEmpty {
            let next = queued.removeFirst()
            waiting[key] = queued.isEmpty ? nil : queued
            next.resume()
        } else {
            active.remove(key)
        }
    }
}
