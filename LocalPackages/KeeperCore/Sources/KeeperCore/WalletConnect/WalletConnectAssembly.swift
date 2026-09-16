import ChainKit
import Foundation
import ReownWalletKit
import TKLogging

public final class WalletConnectAssembly {
    public private(set) lazy var walletConnectDeeplinkValidator: WalletConnectDeeplinkValidator = WalletConnectDeeplinkValidatorImplementation()

    public private(set) lazy var walletConnectSigningService: WalletConnectSigningService = WalletConnectSigningService(
        mnemonicAccess: mnemonicAccess,
        client: chainKitClient,
        pendingTransactionsService: pendingTransactionsService
    )

    @WalletConnectActor
    public private(set) lazy var walletConnectService: WalletConnectService = WalletConnectServiceImplementation(
        eventStream: walletConnectEventStream,
        network: walletConnectWalletKitClient,
        sessionRepository: walletConnectSessionRepository,
        pairingSourceStore: walletConnectPairingSourceStore,
        autoRejectService: WalletConnectAutoRejectService(
            network: walletConnectWalletKitClient
        )
    )

    @WalletConnectActor
    public private(set) lazy var walletConnectWalletsSynchronizer = WalletConnectWalletsSynchronizer(
        walletConnectService: walletConnectService,
        walletsStore: walletsStore
    )

    @WalletConnectActor
    private lazy var walletConnectWalletKitClient = WalletConnectWalletKitClient(
        configurationProvider: walletConnectConfiguration,
        networkConnectionStatusProvider: walletConnectNetworkConnectionStatusProvider
    )

    @WalletConnectActor
    private lazy var walletConnectNetworkConnectionStatusProvider = WalletConnectNetworkConnectionStatusProvider()

    @WalletConnectActor
    private lazy var walletConnectEventStream = WalletConnectEventStream()

    @WalletConnectActor
    private lazy var walletConnectSessionRepository = WalletConnectSessionRepository(
        store: walletConnectSessionStore
    )

    @WalletConnectActor
    private lazy var walletConnectSessionStore: WalletConnectSessionStore = WalletConnectSessionStore(
        vault: coreAssembly.sharedFileSystemVault()
    )

    @WalletConnectActor
    private lazy var walletConnectPairingSourceStore: WalletConnectPairingSourceStore = WalletConnectPairingSourceStore(
        vault: coreAssembly.sharedFileSystemVault()
    )

    @WalletConnectActor
    private func walletConnectConfiguration() throws(WalletConnectConfigurationError) -> WalletConnectConfiguration {
        try WalletConnectConfiguration(
            projectId: "81bb6dac2849cc0dd57bdc40e14f1db8",
            relayHost: "relay.walletconnect.org",
            groupIdentifier: Bundle.main.object(
                forInfoDictionaryKey: "APP_GROUP_IDENTIFIER"
            ) as? String ?? "",
            metadata: AppMetadata(
                name: "Keeper",
                description: "Keeper wallet",
                url: "https://tonkeeper.com/",
                icons: ["https://tonkeeper.com/assets/tonkeeper-logo.png"],
                redirect: walletConnectRedirect()
            )
        )
    }

    @WalletConnectActor
    private func walletConnectRedirect() throws(WalletConnectConfigurationError) -> AppMetadata.Redirect {
        do {
            return try AppMetadata.Redirect(
                native: "tonkeeper://wc",
                universal: "https://app.tonkeeper.com/wc"
            )
        } catch {
            Log.e("WalletConnect: failed to create app metadata redirect", error: error)
            throw .invalidRedirect
        }
    }

    private let mnemonicAccess: MnemonicAccess
    private let coreAssembly: CoreAssembly
    private let walletsStore: WalletsStore
    private let chainKitClient: CryptoKitClient
    private let pendingTransactionsService: PendingTransactionsService

    init(
        mnemonicAccess: MnemonicAccess,
        coreAssembly: CoreAssembly,
        walletsStore: WalletsStore,
        chainKitClient: CryptoKitClient,
        pendingTransactionsService: PendingTransactionsService
    ) {
        self.mnemonicAccess = mnemonicAccess
        self.coreAssembly = coreAssembly
        self.walletsStore = walletsStore
        self.chainKitClient = chainKitClient
        self.pendingTransactionsService = pendingTransactionsService
    }
}
