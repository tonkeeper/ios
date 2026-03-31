import Foundation
import TONWalletKit

public final class TONWalletKitAssembly {
    public let tonWalletKit: TONWalletKit
    public let walletsSynchronizer: TONWalletKitWalletsSynchronizer
    public let eventsHandler: TONConnectEventsHandler

    init(
        storesAssembly: StoresAssembly,
        tonConnectAssembly: TonConnectAssembly,
        apiAssembly: APIAssembly
    ) {
        self.tonWalletKit = TONWalletKit(
            tonConnectService: tonConnectAssembly.tonConnectService(),
            walletsStore: storesAssembly.walletsStore,
            appsStore: tonConnectAssembly.tonConnectAppsStore,
            bridgeURL: apiAssembly.tonConnectBridgeURL
        )
        self.walletsSynchronizer = TONWalletKitWalletsSynchronizer(
            tonWalletKit: tonWalletKit,
            walletsStore: storesAssembly.walletsStore
        )
        self.eventsHandler = TONConnectEventsHandler(
            walletsStore: storesAssembly.walletsStore,
            tonConnectAppsStore: tonConnectAssembly.tonConnectAppsStore
        )
    }
}
