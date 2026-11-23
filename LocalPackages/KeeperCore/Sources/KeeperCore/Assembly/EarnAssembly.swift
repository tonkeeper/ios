import Foundation
import KeeperCoreComponents
import TKFeatureFlags

public final class EarnAssembly {
    public let vaultsRepository: EarnVaultsRepository
    public let assetOffersRepository: EarnAssetOffersRepository
    public let portfolioStore: EarnPortfolioStore
    public let portfolioDirtyFlags = EarnPortfolioDirtyFlags()
    let portfolioLoader: EarnPortfolioLoader

    init(
        apiAssembly: APIAssembly,
        appInfoProvider: AppInfoProvider,
        configuration: Configuration,
        walletsStore: WalletsStore,
        fileSystemVault: FileSystemVault<EarnPortfolio, String>,
        walletAuth: @escaping @Sendable () -> MultichainWalletAuthDependencies?
    ) {
        let api = EarnAPIImplementation(
            makeClient: { [apiAssembly, appInfoProvider] in
                await apiAssembly.earnAPIClient(userAgent: appInfoProvider.userAgent)
            },
            makeWalletClient: { [apiAssembly, appInfoProvider] walletId in
                let dependencies = walletAuth()
                let session = try? await dependencies?.deviceAuth.session()
                let accessToken = session?.accessToken ?? ""
                var walletAuthToken: String?
                if let dependencies {
                    walletAuthToken = await dependencies.walletAuthTokenProvider.token(
                        walletId: walletId,
                        accessToken: accessToken
                    )
                }
                return await apiAssembly.walletAuthEarnAPIClient(
                    deviceJWT: accessToken,
                    walletId: walletId,
                    walletAuthToken: walletAuthToken,
                    recovery: dependencies,
                    userAgent: appInfoProvider.userAgent
                )
            }
        )
        let isEnabled: @Sendable () -> Bool = { configuration.featureEnabled(.earnEnabled) }
        let vaultsRepository = EarnVaultsRepositoryImplementation(api: api, isEnabled: isEnabled)
        self.vaultsRepository = vaultsRepository
        assetOffersRepository = vaultsRepository
        let portfolioStore = EarnPortfolioStore(
            walletsStore: walletsStore,
            repository: EarnPortfolioRepository(fileSystemVault: fileSystemVault)
        )
        self.portfolioStore = portfolioStore
        portfolioLoader = EarnPortfolioLoader(
            api: api,
            store: portfolioStore,
            dirtyFlags: portfolioDirtyFlags,
            isEnabled: isEnabled
        )
    }
}
