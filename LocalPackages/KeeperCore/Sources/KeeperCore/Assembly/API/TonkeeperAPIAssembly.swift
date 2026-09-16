import Foundation

public final class TonkeeperAPIAssembly {
    private let appInfoProvider: AppInfoProvider
    private let coreAssembly: CoreAssembly
    private let configuration: Configuration
    private let isMultichainEnabled: @Sendable () -> Bool

    init(
        appInfoProvider: AppInfoProvider,
        coreAssembly: CoreAssembly,
        configuration: Configuration,
        isMultichainEnabled: @escaping @Sendable () -> Bool
    ) {
        self.appInfoProvider = appInfoProvider
        self.coreAssembly = coreAssembly
        self.configuration = configuration
        self.isMultichainEnabled = isMultichainEnabled
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
            configuration: configuration,
            isMultichainEnabled: isMultichainEnabled
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
