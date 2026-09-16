import Foundation

public final class RootController {
    private let configuration: Configuration
    private let deeplinkParser: DeeplinkParser
    private let keeperInfoRepository: KeeperInfoRepository
    private let knownAccountsProvider: KnownAccountsProvider

    init(
        configuration: Configuration,
        deeplinkParser: DeeplinkParser,
        keeperInfoRepository: KeeperInfoRepository,
        knownAccountsProvider: KnownAccountsProvider
    ) {
        self.configuration = configuration
        self.deeplinkParser = deeplinkParser
        self.keeperInfoRepository = keeperInfoRepository
        self.knownAccountsProvider = knownAccountsProvider
    }

    public func loadConfigurations() {
        knownAccountsProvider.load()
        Task {
            await configuration.loadConfigurations()
        }
    }

    public func parseDeeplink(string: String?) throws -> Deeplink {
        try deeplinkParser.parse(string: string)
    }
}
