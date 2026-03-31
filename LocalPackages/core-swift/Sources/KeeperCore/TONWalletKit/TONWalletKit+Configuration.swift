import Foundation
import TONWalletKit

extension TONWalletKit {
    convenience init(
        tonConnectService: TonConnectService,
        walletsStore: WalletsStore,
        appsStore: TonConnectAppsStore,
        bridgeURL: URL
    ) {
        let bridgeURL = bridgeURL.absoluteString
        let apiClientConfig = TONWalletKitConfiguration.APIClientConfiguration(key: "")
        let mainNetworkConfiguration = TONWalletKitConfiguration.NetworkConfiguration(
            network: .mainnet,
            apiClientConfiguration: apiClientConfig
        )
        let testNetworkConfiguration = TONWalletKitConfiguration.NetworkConfiguration(
            network: .testnet,
            apiClientConfiguration: apiClientConfig
        )
        
        let tetraNetworkConfiguration = TONWalletKitConfiguration.NetworkConfiguration(
            network: .init(chainId: String(Network.tetra.rawValue)),
            apiClientConfiguration: apiClientConfig
        )

        let sessionManager = TONConnectSessionsManagerAdapter(
            tonConnectService: tonConnectService,
            walletsStore: walletsStore,
            appsStore: appsStore
        )

        let configuration = TONWalletKitConfiguration(
            networkConfigurations: [mainNetworkConfiguration, testNetworkConfiguration, tetraNetworkConfiguration],
            walletManifest: TONWalletKitConfiguration.Manifest(
                // TODO: Move constant for name and appName into some other place
                // Currently there is already a constant for appName in InforProvider but it's in TKCore,
                // and it's not possible to connect TKCore to core-swift due recursive dependency issue
                name: "tonkeeper",
                appName: "Tonkeeper",
                imageUrl: "https://tonkeeper.com/assets/tonkeeper-logo.png",
                aboutUrl: "https://tonkeeper.com",
                universalLink: "https://app.tonkeeper.com/ton-connect",
                bridgeUrl: bridgeURL
            ),
            storage: .keychain,
            sessionManager: sessionManager,
            bridge: TONWalletKitConfiguration.Bridge(bridgeUrl: bridgeURL, webViewInjectionKey: "tonkeeper"),
            eventsConfiguration: TONWalletKitConfiguration.EventsConfiguration(disableTransactionEmulation: true),
            features: [
                TONSendTransactionFeature(maxMessages: 255),
                TONSignDataFeature(types: [.text, .binary, .cell]),
            ],
            devConfiguration: TONWalletKitConfiguration.DevConfiguration(disableNetworkSend: true)
        )

        self.init(configuration: configuration)
    }
}
