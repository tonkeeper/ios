import Foundation

public final class WalletsUpdateAssembly {
    public let storesAssembly: StoresAssembly
    public let servicesAssembly: ServicesAssembly
    public let repositoriesAssembly: RepositoriesAssembly
    public let formattersAssembly: FormattersAssembly
    public let secureAssembly: SecureAssembly
    public let configurationAssembly: ConfigurationAssembly

    init(
        storesAssembly: StoresAssembly,
        servicesAssembly: ServicesAssembly,
        repositoriesAssembly: RepositoriesAssembly,
        formattersAssembly: FormattersAssembly,
        secureAssembly: SecureAssembly,
        configurationAssembly: ConfigurationAssembly
    ) {
        self.storesAssembly = storesAssembly
        self.servicesAssembly = servicesAssembly
        self.repositoriesAssembly = repositoriesAssembly
        self.formattersAssembly = formattersAssembly
        self.secureAssembly = secureAssembly
        self.configurationAssembly = configurationAssembly
    }

    public func walletAddController(
        multichainAssembly: MultichainAssembly
    ) -> WalletAddController {
        WalletAddController(
            walletsStore: storesAssembly.walletsStore,
            tonProofTokenService: servicesAssembly.tonProofTokenService(),
            mnemonicAccess: secureAssembly.mnemonicAccess,
            tronBalanceService: servicesAssembly.tronBalanceService(),
            multichainAssembly: multichainAssembly
        )
    }

    public func walletImportController() -> WalletImportController {
        WalletImportController(
            activeWalletService: servicesAssembly.activeWalletsService(),
            currencyService: servicesAssembly.currencyService()
        )
    }

    public func importWalletKindPreviewLoader(
        multichainAssembly: MultichainAssembly
    ) -> ImportWalletKindPreviewLoader {
        ImportWalletKindPreviewLoader(
            walletImportController: walletImportController(),
            importedWalletTronResolver: ImportedWalletTronResolver(
                tronBalanceService: servicesAssembly.tronBalanceService()
            ),
            multichainService: servicesAssembly.multichainService(),
            chainKitService: multichainAssembly.chainKitService,
            walletSynchronizer: multichainAssembly.walletSynchronizer,
            walletAuthEphemeralKeyProvider: multichainAssembly.walletAuthTokenProvider,
            ratesService: servicesAssembly.ratesService()
        )
    }

    public func watchOnlyWalletAddressInputController() -> WatchOnlyWalletAddressInputController {
        WatchOnlyWalletAddressInputController(
            addressResolver: AddressResolver(dnsService: servicesAssembly.dnsService())
        )
    }
}
