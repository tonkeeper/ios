import Foundation
import TonSwift
import BigInt

public final class MainAssembly {
  
  public let repositoriesAssembly: RepositoriesAssembly
  public let walletAssembly: WalletAssembly
  public let walletUpdateAssembly: WalletsUpdateAssembly
  public let servicesAssembly: ServicesAssembly
  public let storesAssembly: StoresAssembly
  public let formattersAssembly: FormattersAssembly
  public let mappersAssembly: MappersAssembly
  public let configurationAssembly: ConfigurationAssembly
  public let passcodeAssembly: PasscodeAssembly
  public let tonConnectAssembly: TonConnectAssembly
  public let mainStoresAssembly: MainStoresAssembly
  public let mainLoadersAssembly: MainLoadersAssembly
  public let loadersAssembly: LoadersAssembly
  let apiAssembly: APIAssembly
  
  init(repositoriesAssembly: RepositoriesAssembly,
       walletAssembly: WalletAssembly,
       walletUpdateAssembly: WalletsUpdateAssembly,
       servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       formattersAssembly: FormattersAssembly,
       mappersAssembly: MappersAssembly,
       configurationAssembly: ConfigurationAssembly,
       passcodeAssembly: PasscodeAssembly,
       tonConnectAssembly: TonConnectAssembly,
       mainStoresAssembly: MainStoresAssembly,
       mainLoadersAssembly: MainLoadersAssembly,
       apiAssembly: APIAssembly,
       loadersAssembly: LoadersAssembly) {
    self.repositoriesAssembly = repositoriesAssembly
    self.walletAssembly = walletAssembly
    self.walletUpdateAssembly = walletUpdateAssembly
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.formattersAssembly = formattersAssembly
    self.mappersAssembly = mappersAssembly
    self.configurationAssembly = configurationAssembly
    self.passcodeAssembly = passcodeAssembly
    self.tonConnectAssembly = tonConnectAssembly
    self.mainStoresAssembly = mainStoresAssembly
    self.mainLoadersAssembly = mainLoadersAssembly
    self.apiAssembly = apiAssembly
    self.loadersAssembly = loadersAssembly
  }
  
  public func scannerAssembly() -> ScannerAssembly {
    ScannerAssembly()
  }
  
  public func mainController() -> MainController {
    MainController(
      walletsStore: walletAssembly.walletsStore,
      accountNFTService: servicesAssembly.accountNftService(),
      backgroundUpdateUpdater: mainStoresAssembly.backgroundUpdateUpdater,
      tonConnectEventsStore: tonConnectAssembly.tonConnectEventsStore,
      knownAccountsStore: storesAssembly.knownAccountsStore,
      balanceStore: mainStoresAssembly.balanceStore,
      dnsService: servicesAssembly.dnsService(),
      tonConnectService: tonConnectAssembly.tonConnectService(),
      deeplinkParser: DefaultDeeplinkParser(
        parsers: [
          TonkeeperDeeplinkParser(),
          TonConnectDeeplinkParser(),
          TonDeeplinkParser(),
        ]
      ),
      apiProvider: apiAssembly.apiProvider,
      walletStateLoader: mainLoadersAssembly.walletStateLoader,
      tonRatesLoader: loadersAssembly.tonRatesLoaderV2,
      internalNotificationsLoader: loadersAssembly.internalNotificationsLoader
    )
  }

  public var walletDeleteController: WalletDeleteController {
    WalletDeleteController(walletStore: storesAssembly.walletsStore,
                           keeperInfoStore: storesAssembly.keeperInfoStoreV3,
                           mnemonicsRepository: repositoriesAssembly.mnemonicsRepository())
  }
  
  public func historyController() -> HistoryController {
    HistoryController(walletsStore: walletAssembly.walletsStore,
                      backgroundUpdateStore: mainStoresAssembly.backgroundUpdateStore)
  }
  
  public func historyListController(wallet: Wallet) -> HistoryListController {
    let loader = HistoryListAllEventsLoader(
      historyService: servicesAssembly.historyService()
    )
    let paginator = HistoryListPaginator(
      wallet: wallet,
      loader: loader,
      nftService: servicesAssembly.nftService(),
      accountEventMapper: accountEventMapper,
      dateFormatter: formattersAssembly.dateFormatter
    )
    return HistoryListController(
      walletsStore: walletAssembly.walletsStore,
      paginator: paginator,
      backgroundUpdateUpdater: mainStoresAssembly.backgroundUpdateUpdater)
  }
  
  public func tonEventsHistoryListController(wallet: Wallet) -> HistoryListController {
    let loader = HistoryListTonEventsLoader(
      historyService: servicesAssembly.historyService()
    )
    let paginator = HistoryListPaginator(
      wallet: wallet,
      loader: loader,
      nftService: servicesAssembly.nftService(),
      accountEventMapper: accountEventMapper,
      dateFormatter: formattersAssembly.dateFormatter
    )
    return HistoryListController(
      walletsStore: walletAssembly.walletsStore,
      paginator: paginator,
      backgroundUpdateUpdater: mainStoresAssembly.backgroundUpdateUpdater)
  }
  
  public func jettonEventsHistoryListController(jettonItem: JettonItem, wallet: Wallet) -> HistoryListController {
    let loader = HistoryListJettonEventsLoader(
      jettonInfo: jettonItem.jettonInfo,
      historyService: servicesAssembly.historyService()
    )
    let paginator = HistoryListPaginator(
      wallet: wallet,
      loader: loader,
      nftService: servicesAssembly.nftService(),
      accountEventMapper: accountEventMapper,
      dateFormatter: formattersAssembly.dateFormatter
    )
    return HistoryListController(
      walletsStore: walletAssembly.walletsStore,
      paginator: paginator,
      backgroundUpdateUpdater: mainStoresAssembly.backgroundUpdateUpdater)
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
  
  public func historyEventDetailsController(event: AccountEventDetailsEvent) -> HistoryEventDetailsController {
    HistoryEventDetailsController(
      event: event,
      amountMapper: PlainAccountEventAmountMapper(amountFormatter: formattersAssembly.amountFormatter),
      tonRatesStore: storesAssembly.tonRatesStore,
      walletsStore: walletAssembly.walletsStore,
      currencyStore: storesAssembly.currencyStore,
      nftService: servicesAssembly.nftService()
    )
  }
  
  public func sendV3Controller() -> SendV3Controller {
    SendV3Controller(
      walletsStore: walletAssembly.walletsStore,
      balanceStore: mainStoresAssembly.convertedBalanceStore,
      knownAccountsStore: storesAssembly.knownAccountsStore,
      dnsService: servicesAssembly.dnsService(),
      tonRatesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      amountFormatter: formattersAssembly.amountFormatter
    )
  }
  
  public func sendRecipientController(recipient: Recipient?) -> SendRecipientController {
    SendRecipientController(
      recipient: recipient,
      knownAccountsStore: storesAssembly.knownAccountsStore,
      dnsService: servicesAssembly.dnsService()
    )
  }
  
  public func sendCommentController(isCommentRequired: Bool,
                                    comment: String?) -> SendCommentController {
    SendCommentController(
      isCommentRequired: isCommentRequired,
      comment: comment
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
      balanceStore: mainStoresAssembly.balanceStore,
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
      balanceStore: mainStoresAssembly.balanceStore,
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
      balanceStore: mainStoresAssembly.balanceStore,
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
      configurationStore: configurationAssembly.remoteConfigurationStore,
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
      walletsStore: walletAssembly.walletsStore,
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
