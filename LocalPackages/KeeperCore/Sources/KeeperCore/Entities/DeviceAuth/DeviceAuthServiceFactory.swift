import ChainKit
import TKKeychain

enum DeviceAuthServiceFactory {
    static func make(
        api: DeviceAuthAPI,
        keychainVault: TKKeychainVault,
        tokenStore: DeviceTokenStore,
        appInfoProvider: AppInfoProvider,
        appIdProvider: @escaping @Sendable () -> Int64?,
        didChangeDevice: @escaping () -> Void
    ) -> DeviceAuthProviding {
        DeviceAuthService(
            api: api,
            signer: ChainKitDeviceCertificateSigner(auth: WalletAuth()),
            certificateStore: DeviceCertificateStore(keychainVault: keychainVault),
            tokenStore: tokenStore,
            platform: appInfoProvider.platform,
            clientVersion: appInfoProvider.version,
            appIdProvider: appIdProvider,
            didChangeDevice: didChangeDevice
        )
    }
}
