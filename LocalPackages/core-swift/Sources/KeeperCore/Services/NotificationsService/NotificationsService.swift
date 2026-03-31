import Foundation

public protocol NotificationsService {
    func turnOnDappNotifications(
        wallet: Wallet,
        manifest: TonConnectManifest,
        sessionId: String?,
        token: String
    ) async throws -> Bool
    func turnOffDappNotifications(
        wallet: Wallet,
        manifest: TonConnectManifest,
        sessionId: String?,
        token: String
    ) async throws -> Bool
}

final class NotificationsServiceImplementation: NotificationsService {
    enum Error: Swift.Error {
        case invalidDapp(String)
    }

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

    func turnOnDappNotifications(
        wallet: Wallet,
        manifest: TonConnectManifest,
        sessionId: String?,
        token: String
    ) async throws -> Bool {
        _ = try tonConnectAppsStore.connectedApps(forWallet: wallet)
        let tonProof = try tonProofTokenService.getWalletToken(wallet)
        let isPushNotificationsOn = walletNotificationsStore.getState()[wallet]?.isOn ?? false

        let data = try PushNotificationsAPI.DappSubscribeData(
            token: token,
            appURL: manifest.url.absoluteString,
            account: wallet.address.toRaw(),
            tonProof: tonProof,
            sessionId: sessionId,
            commercial: true,
            silent: !isPushNotificationsOn
        )
        return try await pushNotificationAPI.subscribeDappNotifications(subscribeData: data)
    }

    func turnOffDappNotifications(
        wallet: Wallet,
        manifest: TonConnectManifest,
        sessionId: String?,
        token: String
    ) async throws -> Bool {
        _ = try tonConnectAppsStore.connectedApps(forWallet: wallet)
        let tonProof = try tonProofTokenService.getWalletToken(wallet)

        let data = try PushNotificationsAPI.DappUnsubscribeData(
            token: token,
            appURL: manifest.url.absoluteString,
            account: wallet.address.toRaw(),
            tonProof: tonProof
        )

        return try await pushNotificationAPI.unsubscribeDappNotifications(unsubscribeData: data)
    }
}
