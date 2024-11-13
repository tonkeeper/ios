import Foundation

public final class ServicesAssembly {

  private let repositoriesAssembly: RepositoriesAssembly
  private let apiAssembly: APIAssembly
  private let tonkeeperAPIAssembly: TonkeeperAPIAssembly
  private let locationAPIAsembly: LocationAPIAssembly
  private let scamAPIAssembly: ScamAPIAssembly
  private let coreAssembly: CoreAssembly
  private let secureAssembly: SecureAssembly
  private let batteryAssembly: BatteryAssembly
  
  init(repositoriesAssembly: RepositoriesAssembly,
       apiAssembly: APIAssembly,
       tonkeeperAPIAssembly: TonkeeperAPIAssembly,
       locationAPIAsembly: LocationAPIAssembly,
       scamAPIAssembly: ScamAPIAssembly,
       coreAssembly: CoreAssembly,
       secureAssembly: SecureAssembly,
       batteryAssembly: BatteryAssembly) {
    self.repositoriesAssembly = repositoriesAssembly
    self.apiAssembly = apiAssembly
    self.tonkeeperAPIAssembly = tonkeeperAPIAssembly
    self.locationAPIAsembly = locationAPIAsembly
    self.scamAPIAssembly = scamAPIAssembly
    self.coreAssembly = coreAssembly
    self.secureAssembly = secureAssembly
    self.batteryAssembly = batteryAssembly
  }
  
  public func walletsService() -> WalletsService {
    WalletsServiceImplementation(keeperInfoRepository: repositoriesAssembly.keeperInfoRepository())
  }
  
  func balanceService() -> BalanceService {
    BalanceServiceImplementation(
      tonBalanceService: tonBalanceService(),
      jettonsBalanceService: jettonsBalanceService(),
      batteryService: batteryAssembly.batteryService(),
      stackingService: stackingService(),
      tonProofTokenService: tonProofTokenService(),
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
  
  public func stackingService() -> StakingService {
    StakingServiceImplementation(apiProvider: apiAssembly.apiProvider)
  }

  func activeWalletsService() -> ActiveWalletsService {
    ActiveWalletsServiceImplementation(
      apiProvider: apiAssembly.apiProvider,
      jettonsBalanceService: jettonsBalanceService(),
      accountNFTService: accountNftService(),
      walletsService: walletsService()
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
  
  public func historyService() -> HistoryService {
    HistoryServiceImplementation(
      apiProvider: apiAssembly.apiProvider,
      repository: repositoriesAssembly.historyRepository()
    )
  }
  
  public func nftService() -> NFTService {
    NFTServiceImplementation(
      apiProvider: apiAssembly.apiProvider,
      scamAPI: scamAPIAssembly.api,
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
  
  public func sendService() -> SendService {
    SendServiceImplementation(apiProvider: apiAssembly.apiProvider)
  }
  
  public func dnsService() -> DNSService {
    DNSServiceImplementation(apiProvider: apiAssembly.apiProvider)
  }
  
  public func locationService() -> LocationService {
    LocationServiceImplementation(locationAPI: locationAPIAsembly.locationAPI())
  }
  
  public func popularAppsService() -> PopularAppsService {
    PopularAppsServiceImplementation(api: tonkeeperAPIAssembly.api,
                                     popularAppsRepository: repositoriesAssembly.popularAppsRepository())
  }
  
  public func encryptedCommentService() -> EncryptedCommentService {
    EncryptedCommentServiceImplementation(mnemonicsRepository: secureAssembly.mnemonicsRepository())
  }

  public func searchEngineService() -> SearchEngineServiceProtocol {
    SearchEngineService(session: .shared)
  }
  
  public func tonProofTokenService() -> TonProofTokenService {
    TonProofTokenServiceImplementation(
      keeperInfoRepository: repositoriesAssembly.keeperInfoRepository(),
      tonProofTokenRepository: repositoriesAssembly.tonProofTokenRepository(),
      mnemonicsRepository: secureAssembly.mnemonicsRepository(),
      api: apiAssembly.api
    )
  }
}
