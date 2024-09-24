import Foundation
import TonSwift
import BigInt

public final class MainAssembly {
  public let appInfoProvider: AppInfoProvider
  public let repositoriesAssembly: RepositoriesAssembly
  public let walletUpdateAssembly: WalletsUpdateAssembly
  public let servicesAssembly: ServicesAssembly
  public let storesAssembly: StoresAssembly
  public let formattersAssembly: FormattersAssembly
  public let mappersAssembly: MappersAssembly
  public let configurationAssembly: ConfigurationAssembly
  public let passcodeAssembly: PasscodeAssembly
  public let tonConnectAssembly: TonConnectAssembly
  public let loadersAssembly: LoadersAssembly
  let apiAssembly: APIAssembly
  
  init(appInfoProvider: AppInfoProvider,
       repositoriesAssembly: RepositoriesAssembly,
       walletUpdateAssembly: WalletsUpdateAssembly,
       servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       formattersAssembly: FormattersAssembly,
       mappersAssembly: MappersAssembly,
       configurationAssembly: ConfigurationAssembly,
       passcodeAssembly: PasscodeAssembly,
       tonConnectAssembly: TonConnectAssembly,
       apiAssembly: APIAssembly,
       loadersAssembly: LoadersAssembly) {
    self.appInfoProvider = appInfoProvider
    self.repositoriesAssembly = repositoriesAssembly
    self.walletUpdateAssembly = walletUpdateAssembly
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.formattersAssembly = formattersAssembly
    self.mappersAssembly = mappersAssembly
    self.configurationAssembly = configurationAssembly
    self.passcodeAssembly = passcodeAssembly
    self.tonConnectAssembly = tonConnectAssembly
    self.apiAssembly = apiAssembly
    self.loadersAssembly = loadersAssembly
  }
  
  public func scannerAssembly() -> ScannerAssembly {
    ScannerAssembly()
  }
  
  public func mainController() -> MainController {
    MainController(
      backgroundUpdateUpdater: storesAssembly.backgroundUpdateUpdater,
      tonConnectEventsStore: tonConnectAssembly.tonConnectEventsStore,
      tonConnectService: tonConnectAssembly.tonConnectService(),
      deeplinkParser: DeeplinkParser(),
      walletStateLoader: loadersAssembly.walletStateLoader,
      internalNotificationsLoader: loadersAssembly.internalNotificationsLoader
    )
  }

  public var walletDeleteController: WalletDeleteController {
    WalletDeleteController(walletStore: storesAssembly.walletsStore,
                           keeperInfoStore: storesAssembly.keeperInfoStore,
                           mnemonicsRepository: repositoriesAssembly.mnemonicsRepository())
  }
  
  public func chartController() -> ChartController {
    ChartController(
      chartService: servicesAssembly.chartService(),
      tonRatesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      decimalAmountFormatter: formattersAssembly.decimalAmountFormatter
    )
  }
  
  public func chartV2Controller(token: Token) -> ChartV2Controller {
    ChartV2Controller(
      token: token,
      loader: loadersAssembly.chartLoader,
      chartService: servicesAssembly.chartService(),
      currencyStore: storesAssembly.currencyStore,
      walletsService: servicesAssembly.walletsService(),
      decimalAmountFormatter: formattersAssembly.decimalAmountFormatter
    )
  }
  
  public func historyEventDetailsController(event: AccountEventDetailsEvent,
                                            isTestnet: Bool) -> HistoryEventDetailsController {
    HistoryEventDetailsController(
      event: event,
      amountMapper: PlainAccountEventAmountMapper(amountFormatter: formattersAssembly.amountFormatter),
      tonRatesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      nftService: servicesAssembly.nftService(),
      isTestnet: isTestnet
    )
  }
  
  public func sendV3Controller(wallet: Wallet) -> SendV3Controller {
    SendV3Controller(
      wallet: wallet,
      balanceStore: storesAssembly.convertedBalanceStore,
      knownAccountsStore: loadersAssembly.knownAccountsStore,
      dnsService: servicesAssembly.dnsService(),
      tonRatesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      recipientResolver: loadersAssembly.recipientResolver(),
      amountFormatter: formattersAssembly.amountFormatter
    )
  }
  
  public func sendConfirmationController(wallet: Wallet,
                                         recipient: Recipient,
                                         sendItem: SendItem,
                                         comment: String?) -> SendConfirmationController {
    SendConfirmationController(
      wallet: wallet,
      recipient: recipient,
      sendItem: sendItem,
      comment: comment,
      sendService: servicesAssembly.sendService(),
      accountService: servicesAssembly.accountService(),
      blockchainService: servicesAssembly.blockchainService(),
      balanceStore: storesAssembly.balanceStore,
      ratesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      amountFormatter: formattersAssembly.amountFormatter
    )
  }
  
  public func stakingDepositConfirmationController(wallet: Wallet,
                                                   stakingPool: StackingPoolInfo,
                                                   amount: BigUInt,
                                                   isMax: Bool) -> StakeConfirmationController {
    StakeDepositConfirmationController(
      wallet: wallet,
      stakingPool: stakingPool,
      amount: amount,
      isMax: isMax,
      sendService: servicesAssembly.sendService(),
      accountService: servicesAssembly.accountService(),
      blockchainService: servicesAssembly.blockchainService(),
      balanceStore: storesAssembly.balanceStore,
      ratesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      amountFormatter: formattersAssembly.amountFormatter,
      decimalFormatter: formattersAssembly.decimalAmountFormatter
    )
  }
  
  public func stakingWithdrawConfirmationController(wallet: Wallet,
                                                    stakingPool: StackingPoolInfo,
                                                    amount: BigUInt,
                                                    isMax: Bool,
                                                    isCollect: Bool) -> StakeConfirmationController {
    StakeWithdrawConfirmationController(
      wallet: wallet,
      stakingPool: stakingPool,
      amount: amount,
      isMax: isMax,
      isCollect: isCollect,
      sendService: servicesAssembly.sendService(),
      accountService: servicesAssembly.accountService(),
      blockchainService: servicesAssembly.blockchainService(),
      balanceStore: storesAssembly.balanceStore,
      ratesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      amountFormatter: formattersAssembly.amountFormatter,
      decimalFormatter: formattersAssembly.decimalAmountFormatter
    )
  }
  
  public func buyListController(wallet: Wallet,
                                isMarketRegionPickerAvailable: Bool) -> BuyListController {
    BuyListController(
      wallet: wallet,
      buySellMethodsService: servicesAssembly.buySellMethodsService(),
      locationService: servicesAssembly.locationService(),
      configurationStore: configurationAssembly.configurationStore,
      currencyStore: storesAssembly.currencyStore,
      isMarketRegionPickerAvailable: isMarketRegionPickerAvailable
    )
  }
  
  public func signerSignController(url: URL, wallet: Wallet) -> SignerSignController {
    SignerSignController(url: url, wallet: wallet)
  }
  
  public func browserExploreController() -> BrowserExploreController {
    BrowserExploreController(popularAppsService: servicesAssembly.popularAppsService())
  }
  
  public func browserConnectedController() -> BrowserConnectedController {
    BrowserConnectedController(
      walletsStore: storesAssembly.walletsStore,
      tonConnectAppsStore: tonConnectAssembly.tonConnectAppsStore
    )
  }
  
  public func confirmTransactionController(wallet: Wallet,
                                           bocProvider: ConfirmTransactionControllerBocProvider) -> ConfirmTransactionController {
    ConfirmTransactionController(
      wallet: wallet,
      bocProvider: bocProvider,
      sendService: servicesAssembly.sendService(),
      nftService: servicesAssembly.nftService(),
      tonRatesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      confirmTransactionMapper: ConfirmTransactionMapper(
        accountEventMapper: AccountEventMapper(
          dateFormatter: formattersAssembly.dateFormatter,
          amountFormatter: formattersAssembly.amountFormatter,
          amountMapper: PlainAccountEventAmountMapper(amountFormatter: formattersAssembly.amountFormatter)
        ),
        amountFormatter: formattersAssembly.amountFormatter
      )
    )
  }
  
  public func linkDNSController(wallet: Wallet, nft: NFT) -> LinkDNSController {
    LinkDNSController(
      wallet: wallet,
      nft: nft,
      sendService: servicesAssembly.sendService()
    )
  }
}

private extension MainAssembly {
  var accountEventMapper: AccountEventMapper {
    AccountEventMapper(
      dateFormatter: formattersAssembly.dateFormatter,
      amountFormatter: formattersAssembly.amountFormatter,
      amountMapper: SignedAccountEventAmountMapper(
        plainAccountEventAmountMapper: PlainAccountEventAmountMapper(
          amountFormatter: formattersAssembly.amountFormatter
        )
      )
    )
  }
}
