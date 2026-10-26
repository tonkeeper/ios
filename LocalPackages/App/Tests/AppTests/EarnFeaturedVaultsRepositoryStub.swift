import KeeperCore

struct EarnFeaturedVaultsRepositoryStub: EarnFeaturedVaultsRepository {
    let vaults: [EarnFeaturedVault]

    func featuredVaults() -> [EarnFeaturedVault] {
        vaults
    }
}
