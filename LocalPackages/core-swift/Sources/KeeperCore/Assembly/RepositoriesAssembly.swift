import CoreComponents
import Foundation

public struct RepositoriesAssembly {
    private let coreAssembly: CoreAssembly

    init(coreAssembly: CoreAssembly) {
        self.coreAssembly = coreAssembly
    }

    public func settingsRepository() -> SettingsRepository {
        SettingsRepository(settingsVault: coreAssembly.settingsVault())
    }

    public func keeperInfoRepository() -> KeeperInfoRepository {
        coreAssembly.sharedFileSystemVault()
    }

    func walletBalanceRepository() -> WalletBalanceRepository {
        WalletBalanceRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }

    func walletBalanceRepositoryV2() -> WalletBalanceRepositoryV2 {
        WalletBalanceRepositoryV2implementation(fileSystemVault: coreAssembly.fileSystemVault())
    }

    func ratesRepository() -> RatesRepository {
        RatesRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }

    func historyRepository() -> HistoryRepository {
        HistoryRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }

    func storiesRepository() -> StoriesRepository {
        StoriesRepository(fileSystemVault: coreAssembly.fileSystemVault())
    }

    func nftRepository() -> NFTRepository {
        NFTRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }

    func accountsNftRepository() -> AccountNFTRepository {
        AccountNFTRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }

    func accountNFTsManagementRepository() -> AccountNFTsManagementRepository {
        AccountNFTsManagementRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }

    public func walletNFTRepository() -> WalletNFTsRepository {
        WalletNFTsRepositoryImplementation(
            fileSystemVault: coreAssembly.fileSystemVault()
        )
    }

    func chartDataRepository() -> ChartDataRepository {
        ChartDataRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }

    func popularAppsRepository() -> PopularAppsRepository {
        PopularAppsRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }

    func tokenManagementRepository() -> TokenManagementRepository {
        TokenManagementRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }

    func stakingPoolsInfoRepository() -> StakingPoolsInfoRepository {
        StakingPoolsInfoRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }

    func tonProofTokenRepository() -> TonProofTokenRepository {
        TonProofTokenRepository(keychainVault: coreAssembly.keychainVault)
    }

    public func cookiesRepository() -> CookiesRepository {
        CookiesRepositoryImplementation(fileVault: coreAssembly.fileSystemVault())
    }

    func swapAssetsRepository() -> SwapAssetsRepository {
        SwapAssetsRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }

    func internalNotificationsRepository() -> InternalNotificationsRepository {
        InternalNotificationsRepository(fileSystemVault: coreAssembly.fileSystemVault())
    }

    func onRampRepository() -> OnRampRepository {
        OnRampRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }

    func currenciesRepository() -> CurrenciesRepository {
        CurrenciesRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }
}
