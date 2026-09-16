import Foundation
import TKFeatureFlags

final class TradingAssembly {
    private let tradingAPIAssembly: TradingAPIAssembly
    private let appInfoProvider: AppInfoProvider
    private let repositoriesAssembly: RepositoriesAssembly
    private let coreAssembly: CoreAssembly
    private let configuration: Configuration

    init(
        tradingAPIAssembly: TradingAPIAssembly,
        appInfoProvider: AppInfoProvider,
        repositoriesAssembly: RepositoriesAssembly,
        coreAssembly: CoreAssembly,
        configuration: Configuration
    ) {
        self.tradingAPIAssembly = tradingAPIAssembly
        self.appInfoProvider = appInfoProvider
        self.repositoriesAssembly = repositoriesAssembly
        self.coreAssembly = coreAssembly
        self.configuration = configuration
    }

    private(set) lazy var shelvesService: TradingShelvesService = TradingShelvesServiceImplementation(
        api: tradingAPIAssembly.api,
        cache: shelvesCache,
        marketItemsCache: marketItemsCache,
        requestContextProvider: requestContextProvider
    )

    private(set) lazy var assetsListService: TradingAssetsListService = TradingAssetsListServiceImplementation(
        api: tradingAPIAssembly.api,
        cache: assetsListCache,
        requestContextProvider: requestContextProvider
    )

    private(set) lazy var assetDetailsService: TradingAssetDetailsService = TradingAssetDetailsServiceImplementation(
        api: tradingAPIAssembly.api,
        cache: assetDetailsCache,
        requestContextProvider: requestContextProvider,
        isMultichainEnabled: configuration.featureEnabled(.multichainEnabled)
    )

    private(set) lazy var favoriteAssetsService: TradingFavoriteAssetsService = TradingFavoriteAssetsServiceImplementation(
        fileSystemVault: coreAssembly.fileSystemVault(),
        api: tradingAPIAssembly.api,
        requestContextProvider: requestContextProvider,
        marketItemsCache: marketItemsCache
    )

    var api: TradingAPI {
        tradingAPIAssembly.api
    }

    private lazy var shelvesCache = InMemoryKeyedCache<TradingShelvesMode, TradingShelvesSnapshot>()

    private lazy var assetsListCache =
        InMemoryKeyedCache<TradingAssetsListServiceImplementation.QueryDescriptor, TradingAssetListSnapshot>()

    private lazy var assetDetailsCache = InMemoryKeyedCache<String, TradingAssetDetails>()

    private lazy var marketItemsCache = InMemoryKeyedCache<String, TradingMarketItem>()

    private(set) lazy var requestContextProvider: TradingRequestContextProvider =
        TradingRequestContextProviderImplementation(
            appInfoProvider: appInfoProvider,
            keeperInfoRepository: repositoriesAssembly.keeperInfoRepository()
        )
}
