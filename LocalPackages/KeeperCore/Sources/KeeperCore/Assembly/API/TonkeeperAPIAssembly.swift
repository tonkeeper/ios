import Foundation
import TKFeatureFlags

public final class TonkeeperAPIAssembly {
    private let appInfoProvider: AppInfoProvider
    private let coreAssembly: CoreAssembly
    private let tkAppSettings: TKAppSettings

    init(
        appInfoProvider: AppInfoProvider,
        coreAssembly: CoreAssembly,
        tkAppSettings: TKAppSettings
    ) {
        self.appInfoProvider = appInfoProvider
        self.coreAssembly = coreAssembly
        self.tkAppSettings = tkAppSettings
    }

    public var api: TonkeeperAPI {
        TonkeeperAPIImplementation(
            urlSession: .shared,
            hostProvider: TonkeeperAPIHostProvider(
                defaultHost: apiV1DefaultURL,
                configHost: { [weak self] in
                    self?.apiV1ConfigURL
                }
            ),
            appInfoProvider: appInfoProvider,
            isNewUser: { [tkAppSettings] in tkAppSettings.raffleIsNewUser ?? false }
        )
    }

    var bootConfigurationProvider: BootConfigurationRepository {
        BootConfigurationRepositoryImplementation(
            fileSystemVault: coreAssembly.fileSystemVault()
        )
    }

    var apiV1ConfigURL: URL? {
        guard
            let configuration = try? bootConfigurationProvider.configuration,
            let tonkeeperApiUrl = configuration.mainnet.tonkeeperApiUrl
        else {
            return nil
        }

        return URL(string: tonkeeperApiUrl)
    }

    var apiV1DefaultURL: URL {
        URL(string: "https://api.tonkeeper.com")!
    }
}
