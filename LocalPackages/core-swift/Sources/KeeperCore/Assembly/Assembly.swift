import Foundation
import TKFeatureFlags

public final class Assembly {
    public struct Dependencies {
        public let cacheURL: URL
        public let sharedCacheURL: URL
        public let featureFlags: TKFeatureFlags
        public let tkAppSettings: TKAppSettings
        public let appInfoProvider: AppInfoProvider
        public let seedProvider: () -> String

        public init(
            cacheURL: URL,
            sharedCacheURL: URL,
            appInfoProvider: AppInfoProvider,
            featureFlags: TKFeatureFlags,
            tkAppSettings: TKAppSettings = UserDefaultsTKAppSettings(),
            seedProvider: @escaping () -> String
        ) {
            self.cacheURL = cacheURL
            self.sharedCacheURL = sharedCacheURL
            self.appInfoProvider = appInfoProvider
            self.featureFlags = featureFlags
            self.tkAppSettings = tkAppSettings
            self.seedProvider = seedProvider
        }
    }

    private let coreAssembly: CoreAssembly
    public lazy var repositoriesAssembly = RepositoriesAssembly(
        coreAssembly: coreAssembly
    )
    private lazy var secureAssembly = SecureAssembly(
        coreAssembly: coreAssembly
    )
    public lazy var transactionsManagementAssembly = TransactionsManagementAssembly(
        coreAssembly: coreAssembly,
        scamAPIAssembly: scamAPIAssembly
    )
    private lazy var remoteConfigurationAPIAssembly = RemoteConfigurationAPIAssembly(
        appInfoProvider: dependencies.appInfoProvider
    )
    private lazy var currenciesAPIAssembly = CurrenciesAPIAssembly(
        appInfoProvider: dependencies.appInfoProvider
    )
    private lazy var configurationAssembly = ConfigurationAssembly(
        remoteConfigurationAPIAssembly: remoteConfigurationAPIAssembly,
        featureFlags: dependencies.featureFlags,
        tkAppSettings: dependencies.tkAppSettings,
        coreAssembly: coreAssembly
    )
    private lazy var buySellAssembly = BuySellAssembly(
        tonkeeperApiAssembly: tonkeeperApiAssembly,
        coreAssembly: coreAssembly
    )
    private lazy var knownAccountsAssembly = KnownAccountsAssembly(
        tonkeeperApiAssembly: tonkeeperApiAssembly,
        coreAssembly: coreAssembly
    )

    private lazy var backgroundUpdateAssembly = BackgroundUpdateAssembly(
        apiAssembly: apiAssembly,
        storesAssembly: storesAssembly,
        coreAssembly: coreAssembly
    )
    public lazy var tronUSDTAssembly = TronUSDTAssembly(
        secureAssembly: secureAssembly,
        storesAssembly: storesAssembly,
        batteryAPIAssembly: batteryAPIAssembly,
        configurationAssembly: configurationAssembly
    )

    lazy var apiAssembly = APIAssembly(configurationAssembly: configurationAssembly)
    lazy var tonkeeperApiAssembly = TonkeeperAPIAssembly(
        appInfoProvider: dependencies.appInfoProvider,
        coreAssembly: coreAssembly
    )
    private lazy var scamAPIAssembly = ScamAPIAssembly(configurationAssembly: configurationAssembly)
    private lazy var nativeSwapAPIAssembly = NativeSwapAPIAssembly(configurationAssembly: configurationAssembly)
    private lazy var onRampAPIAssembly = OnRampAPIAssembly(
        configurationAssembly: configurationAssembly,
        appInfoProvider: dependencies.appInfoProvider,
        apiAssembly: apiAssembly
    )
    private lazy var servicesAssembly = ServicesAssembly(
        repositoriesAssembly: repositoriesAssembly,
        storesAssembly: storesAssembly,
        apiAssembly: apiAssembly,
        tonkeeperAPIAssembly: tonkeeperApiAssembly,
        scamAPIAssembly: scamAPIAssembly,
        coreAssembly: coreAssembly,
        secureAssembly: secureAssembly,
        batteryAssembly: batteryAssembly,
        tronUSDTAssembly: tronUSDTAssembly,
        configurationAssembly: configurationAssembly,
        nativeSwapAPIAssembly: nativeSwapAPIAssembly,
        currenciesAPIAssembly: currenciesAPIAssembly,
        onRampAPIAssembly: onRampAPIAssembly
    )
    private lazy var storesAssembly = StoresAssembly(
        apiAssembly: apiAssembly,
        coreAssembly: coreAssembly,
        repositoriesAssembly: repositoriesAssembly
    )
    private lazy var loadersAssembly = LoadersAssembly(
        servicesAssembly: servicesAssembly,
        storesAssembly: storesAssembly,
        tonkeeperAPIAssembly: tonkeeperApiAssembly,
        apiAssembly: apiAssembly,
        knownAccountsAssembly: knownAccountsAssembly,
        tronAssembly: tronUSDTAssembly,
        configurationAssembly: configurationAssembly
    )
    private lazy var formattersAssembly = FormattersAssembly()
    private lazy var mappersAssembly = MappersAssembly(formattersAssembly: formattersAssembly)
    private var walletUpdateAssembly: WalletsUpdateAssembly {
        WalletsUpdateAssembly(
            storesAssembly: storesAssembly,
            servicesAssembly: servicesAssembly,
            repositoriesAssembly: repositoriesAssembly,
            formattersAssembly: formattersAssembly,
            secureAssembly: secureAssembly
        )
    }

    private lazy var rnAssembly = RNAssembly()
    private lazy var batteryAPIAssembly = BatteryAPIAssembly(configurationAssembly: configurationAssembly)
    private lazy var batteryAssembly = BatteryAssembly(
        batteryAPIAssembly: batteryAPIAssembly,
        coreAssembly: coreAssembly,
        configurationAssembly: configurationAssembly
    )

    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
        self.coreAssembly = CoreAssembly(
            cacheURL: dependencies.cacheURL,
            sharedCacheURL: dependencies.sharedCacheURL,
            appInfoProvider: dependencies.appInfoProvider,
            seedProvider: dependencies.seedProvider
        )
    }
}

public extension Assembly {
    func rootAssembly() -> RootAssembly {
        RootAssembly(
            appInfoProvider: dependencies.appInfoProvider,
            repositoriesAssembly: repositoriesAssembly,
            coreAssembly: coreAssembly,
            featureFlags: dependencies.featureFlags,
            servicesAssembly: servicesAssembly,
            storesAssembly: storesAssembly,
            formattersAssembly: formattersAssembly,
            mappersAssembly: mappersAssembly,
            walletsUpdateAssembly: walletUpdateAssembly,
            configurationAssembly: configurationAssembly,
            buySellAssembly: buySellAssembly,
            batteryAssembly: batteryAssembly,
            knownAccountsAssembly: knownAccountsAssembly,
            tonkeeperAPIAssembly: tonkeeperApiAssembly,
            apiAssembly: apiAssembly,
            loadersAssembly: loadersAssembly,
            backgroundUpdateAssembly: backgroundUpdateAssembly,
            rnAssembly: rnAssembly,
            secureAssembly: secureAssembly,
            transactionsManagementAssembly: transactionsManagementAssembly,
            tronUSDTAssembly: tronUSDTAssembly
        )
    }

    func widgetAssembly() -> WidgetAssembly {
        WidgetAssembly(
            repositoriesAssembly: repositoriesAssembly,
            coreAssembly: coreAssembly,
            servicesAssembly: servicesAssembly,
            storesAssembly: storesAssembly,
            formattersAssembly: formattersAssembly,
            walletsUpdateAssembly: walletUpdateAssembly,
            configurationAssembly: configurationAssembly,
            apiAssembly: apiAssembly,
            loadersAssembly: loadersAssembly
        )
    }
}
