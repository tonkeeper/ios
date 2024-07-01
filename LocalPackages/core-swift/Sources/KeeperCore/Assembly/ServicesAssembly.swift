import Foundation

public final class ServicesAssembly {

  private let repositoriesAssembly: RepositoriesAssembly
  private let apiAssembly: APIAssembly
  private let tonkeeperAPIAssembly: TonkeeperAPIAssembly
  private let locationAPIAsembly: LocationAPIAssembly
  private let coreAssembly: CoreAssembly
  
  init(repositoriesAssembly: RepositoriesAssembly,
       apiAssembly: APIAssembly,
       tonkeeperAPIAssembly: TonkeeperAPIAssembly,
       locationAPIAsembly: LocationAPIAssembly,
       coreAssembly: CoreAssembly) {
    self.repositoriesAssembly = repositoriesAssembly
    self.apiAssembly = apiAssembly
    self.tonkeeperAPIAssembly = tonkeeperAPIAssembly
    self.locationAPIAsembly = locationAPIAsembly
    self.coreAssembly = coreAssembly
  }
  
  func walletsService() -> WalletsService {
    WalletsServiceImplementation(keeperInfoRepository: repositoriesAssembly.keeperInfoRepository())
  }
  
  func balanceService() -> BalanceService {
    BalanceServiceImplementation(
      tonBalanceService: tonBalanceService(),
      jettonsBalanceService: jettonsBalanceService(),
      walletBalanceRepository: repositoriesAssembly.walletBalanceRepository())
  }
  
  func tonBalanceService() -> TonBalanceService {
    TonBalanceServiceImplementation(apiProvider: apiAssembly.apiProvider)
  }
  
  func accountService() -> AccountService {
    AccountServiceImplementation(apiProvider: apiAssembly.apiProvider)
  }
  
  func jettonsBalanceService() -> JettonBalanceService {
    JettonBalanceServiceImplementation(apiProvider: apiAssembly.apiProvider)
  }
  
  func totalBalanceService() -> TotalBalanceService {
    TotalBalanceServiceImplementation(
      totalBalanceRepository: repositoriesAssembly.totalBalanceRepository(),
      rateConverter: RateConverter()
    )
  }
  
  func activeWalletsService() -> ActiveWalletsService {
    ActiveWalletsServiceImplementation(
      apiProvider: apiAssembly.apiProvider,
      jettonsBalanceService: jettonsBalanceService(),
      accountNFTService: accountNftService(),
      currencyService: currencyService()
    )
  }
  
  func ratesService() -> RatesService {
    RatesServiceImplementation(
      api: apiAssembly.api,
      ratesRepository: repositoriesAssembly.ratesRepository()
    )
  }
  
  func currencyService() -> CurrencyService {
    CurrencyServiceImplementation(
      keeperInfoRepository: repositoriesAssembly.keeperInfoRepository()
    )
  }
  
  func historyService() -> HistoryService {
    HistoryServiceImplementation(
      apiProvider: apiAssembly.apiProvider,
      repository: repositoriesAssembly.historyRepository()
    )
  }
  
  func nftService() -> NFTService {
    NFTServiceImplementation(
      apiProvider: apiAssembly.apiProvider,
      nftRepository: repositoriesAssembly.nftRepository()
    )
  }
  
  func blockchainService() -> BlockchainService {
    BlockchainServiceImplementation(
      apiProvider: apiAssembly.apiProvider
    )
  }
  
  func accountNftService() -> AccountNFTService {
    AccountNFTServiceImplementation(
      apiProvider: apiAssembly.apiProvider,
      accountNFTRepository: repositoriesAssembly.accountsNftRepository(),
      nftRepository: repositoriesAssembly.nftRepository()
    )
  }
  
  func chartService() -> ChartService {
    ChartServiceImplementation(
      apiProvider: apiAssembly.apiProvider,
      repository: repositoriesAssembly.chartDataRepository()
    )
  }
  
  func securityService() -> SecurityService {
    SecurityServiceImplementation(
      keeperInfoRepository: repositoriesAssembly.keeperInfoRepository()
    )
  }
  
  func setupService() -> SetupService {
    SetupServiceImplementation(
      keeperInfoRepository: repositoriesAssembly.keeperInfoRepository()
    )
  }
  
  public func sendService() -> SendService {
    SendServiceImplementation(apiProvider: apiAssembly.apiProvider)
  }
  
  func dnsService() -> DNSService {
    DNSServiceImplementation(apiProvider: apiAssembly.apiProvider)
  }
  
  func knownAccountsService() -> KnownAccountsService {
    KnownAccountsServiceImplementation(
      session: .shared,
      knownAccountsRepository: repositoriesAssembly.knownAccountsRepository()
    )
  }
  
  func buySellMethodsService() -> BuySellMethodsService {
    BuySellMethodsServiceImplementation(
      api: tonkeeperAPIAssembly.api,
      buySellMethodsRepository: repositoriesAssembly.buySellMethodsRepository()
    )
  }
  
  func locationService() -> LocationService {
    LocationServiceImplementation(locationAPI: locationAPIAsembly.locationAPI())
  }
  
  public func popularAppsService() -> PopularAppsService {
    PopularAppsServiceImplementation(api: tonkeeperAPIAssembly.api,
                                     popularAppsRepository: repositoriesAssembly.popularAppsRepository())
  }
}
