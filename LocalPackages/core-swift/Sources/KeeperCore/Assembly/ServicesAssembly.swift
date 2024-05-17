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
    TonBalanceServiceImplementation(api: apiAssembly.api)
  }
  
  func jettonsBalanceService() -> JettonBalanceService {
    JettonBalanceServiceImplementation(api: apiAssembly.api)
  }
  
  func totalBalanceService() -> TotalBalanceService {
    TotalBalanceServiceImplementation(
      totalBalanceRepository: repositoriesAssembly.totalBalanceRepository(),
      rateConverter: RateConverter()
    )
  }
  
  func activeWalletsService() -> ActiveWalletsService {
    ActiveWalletsServiceImplementation(
      api: apiAssembly.api,
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
      api: apiAssembly.api,
      repository: repositoriesAssembly.historyRepository()
    )
  }
  
  func nftService() -> NFTService {
    NFTServiceImplementation(
      api: apiAssembly.api,
      nftRepository: repositoriesAssembly.nftRepository()
    )
  }
  
  func blockchainService() -> BlockchainService {
    BlockchainServiceImplementation(
      api: apiAssembly.api
    )
  }
  
  func accountNftService() -> AccountNFTService {
    AccountNFTServiceImplementation(
      api: apiAssembly.api,
      accountNFTRepository: repositoriesAssembly.accountsNftRepository(),
      nftRepository: repositoriesAssembly.nftRepository()
    )
  }
  
  func chartService() -> ChartService {
    ChartServiceImplementation(
      api: apiAssembly.api,
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
  
  func sendService() -> SendService {
    SendServiceImplementation(api: apiAssembly.api)
  }
  
  func dnsService() -> DNSService {
    DNSServiceImplementation(api: apiAssembly.api)
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
  
  func stonfiAssetsService() -> StonfiAssetsService {
    StonfiServiceImplementation(
      stonfiApi: apiAssembly.stonfiApi,
      stonfiAssetsRepository: repositoriesAssembly.stonfiAssetsRepository()
    )
  }
  
  func stonfiPairsService() -> StonfiPairsService {
    StonfiPairsServiceImplementation(
      stonfiApi: apiAssembly.stonfiApi,
      stonfiPairsRepository: repositoriesAssembly.stonfiPairsStoreRepository()
    )
  }
}
