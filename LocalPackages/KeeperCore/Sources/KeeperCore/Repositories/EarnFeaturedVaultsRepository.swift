import Foundation

public protocol EarnFeaturedVaultsRepository {
    func featuredVaults() -> [EarnFeaturedVault]
}

struct EarnFeaturedVaultsRepositoryImplementation: EarnFeaturedVaultsRepository {
    private let isEarnEnabled: Bool
    private let isAppStoreEnvironment: Bool
    private let configuration: Configuration

    init(isEarnEnabled: Bool, isAppStoreEnvironment: Bool, configuration: Configuration) {
        self.isEarnEnabled = isEarnEnabled
        self.isAppStoreEnvironment = isAppStoreEnvironment
        self.configuration = configuration
    }

    func featuredVaults() -> [EarnFeaturedVault] {
        guard isEarnEnabled else { return [] }
        let configured = configuration.earnFeaturedVaults
        if configured.isEmpty, !isAppStoreEnvironment {
            return EarnHardcodedData.featuredVaults
        }
        return configured
    }
}
