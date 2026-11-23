import KeeperCore
import LedgerKit
import TKAppInfo
import TKFeatureFlags
import TKKeychain
import TKLogging
import TKServices
import UIKit

public final class CoreAssembly {
    public let appStateTracker = AppStateTracker()
    public let reachabilityTracker = ReachabilityTracker()
    public lazy var ledgerAssembly = LedgerAssembly()
    public let featureFlags: TKFeatureFlags
    public let tkAppSettings: TKAppSettings

    public init(
        featureFlags: TKFeatureFlags? = nil,
        tkAppSettings: TKAppSettings? = nil
    ) {
        self.featureFlags = featureFlags ?? DummyFeatureFlags()
        self.tkAppSettings = tkAppSettings ?? UserDefaultsTKAppSettings()
        Log.d("sharedCacheURL: \(sharedCacheURL)")
        Log.d("cacheURL: \(cacheURL)")
    }

    public var uniqueIdProvider: UniqueIdProvider {
        UniqueIdProvider(
            userDefaults: UserDefaults.standard,
            keychainVault: keychainVault
        )
    }

    public var seedProvider: () -> String {
        { [uniqueIdProvider] in
            uniqueIdProvider.uniqueInstallId.uuidString
        }
    }

    public lazy var analyticsProvider: AnalyticsProvider = {
        let configuration = keeperCoreAssembly.configurationAssembly.configuration
        let aptabaseService = AptabaseConfigurator.makeAnalyticsService(
            installId: uniqueIdProvider.uniqueInstallId.uuidString,
            sendStatsImmediately: TKAppPreferences.sendStatsImmediately,
            reachabilityTracker: reachabilityTracker,
            remoteEndpoint: { [weak configuration] in configuration?.value(\.aptabaseEndpoint) }
        )
        var analyticsServices = [AnalyticsService]()
        #if DEBUG
            analyticsServices.append(ConsoleAnalyticsLogger())
        #endif
        if let aptabaseService {
            analyticsServices.append(aptabaseService)
        }

        return AnalyticsProvider(
            analyticsServices: analyticsServices,
            uniqueIdProvider: uniqueIdProvider,
            deviceIdProvider: { [keeperCoreAssembly] in keeperCoreAssembly.totalAuthDeviceId },
            appInfoProvider: appInfoProvider,
            keysCountryCodeProvider: keysCountryCodeProvider
        )
    }()

    public private(set) lazy var keeperCoreAssembly = KeeperCore.Assembly(
        dependencies: KeeperCore.Assembly.Dependencies(
            cacheURL: cacheURL,
            sharedCacheURL: sharedCacheURL,
            appInfoProvider: appInfoProvider,
            featureFlags: featureFlags,
            tkAppSettings: tkAppSettings,
            seedProvider: seedProvider,
            firebaseUserIdProvider: { [uniqueIdProvider] in uniqueIdProvider.uniqueDeviceId.uuidString },
            pushAppIdProvider: { FirebasePushAppId.current }
        )
    )

    public var keysCountryCodeProvider: KeysCountryCodeProvider {
        KeysCountryCodeProvider(
            countryCodeSource: { [weak self] in
                self?.keeperCoreAssembly.configurationAssembly.configuration.value(\.region)
            }
        )
    }

    public var cacheURL: URL {
        documentsURL
    }

    public var sharedCacheURL: URL {
        AppDirectories.sharedCache
    }

    public var documentsURL: URL {
        AppDirectories.documents
    }

    private lazy var storefrontCountryCodeCache: StorefrontCountryCodeCache = {
        let cache = StorefrontCountryCodeCache()
        cache.warmUp()
        return cache
    }()

    public var appInfoProvider: DeviceAppInfoProvider {
        DeviceAppInfoProvider(
            userDefaults: .standard,
            storefrontCountryCodeCache: storefrontCountryCodeCache
        )
    }

    public var fileManager: FileManager {
        .default
    }

    public func urlOpener() -> URLOpener {
        UIApplication.shared
    }

    public private(set) lazy var appSettings: AppSettings = AppSettings(
        userDefaults: UserDefaults(suiteName: .appSettingsSuiteName) ?? .standard
    )

    /// Install attribution captured before a wallet exists. TK-3415 reads it and
    /// calls `consume` only after the backend accepts the payload.
    public var campaignAttributionStore: CampaignAttributionStore {
        .shared
    }

    public var formattersAssembly: FormattersAssembly {
        FormattersAssembly()
    }

    public var pushNotificationTokenProvider: PushNotificationTokenProvider {
        PushNotificationTokenProvider()
    }

    public var keychainVault: TKKeychainVault {
        TKKeychainVaultImplementation(keychain: TKKeychainImplementation())
    }

    public private(set) lazy var tooltipsAssembly = TooltipsAssembly(
        dependencies: TooltipsAssembly.Dependencies(
            appSettings: appSettings,
            appStoreEnvironment: UIApplication.shared.isAppStoreEnvironment
        )
    )
}

private extension String {
    static let appSettingsSuiteName = "app_settings"
}
