import Foundation

public protocol EarnFeaturedVaultsRepository {
    func featuredVaults() -> [EarnFeaturedVault]
}

struct EarnFeaturedVaultsRepositoryImplementation: EarnFeaturedVaultsRepository {
    private let isEarnEnabled: Bool
    private let configuration: Configuration

    init(isEarnEnabled: Bool, configuration: Configuration) {
        self.isEarnEnabled = isEarnEnabled
        self.configuration = configuration
    }

    func featuredVaults() -> [EarnFeaturedVault] {
        isEarnEnabled ? configuration.earnFeaturedVaults : []
    }
}
