import Foundation

public final class TonkeeperAPIAssembly {
    private let appInfoProvider: AppInfoProvider
    private let coreAssembly: CoreAssembly

    init(appInfoProvider: AppInfoProvider, coreAssembly: CoreAssembly) {
        self.appInfoProvider = appInfoProvider
        self.coreAssembly = coreAssembly
    }

    public var api: TonkeeperAPI {
        TonkeeperAPIImplementation(
            urlSession: .shared,
            defaultHost: apiV1DefaultURL,
            configHost: { [weak self] in
                self?.apiV1ConfigURL
            },
            appInfoProvider: appInfoProvider
        )
    }

    var remoteConfigurationProvider: RemoteConfigurationRepository {
        RemoteConfigurationRepositoryImplementation(
            fileSystemVault: coreAssembly.fileSystemVault()
        )
    }

    var apiV1ConfigURL: URL? {
        guard
            let configuration = try? remoteConfigurationProvider.configuration,
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
