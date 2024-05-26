import Foundation
import TonSwift
import BigInt

public final class MainAssembly {
  
  public struct Dependencies {
    let wallets: [Wallet]
    let activeWallet: Wallet
    
    public init(wallets: [Wallet], activeWallet: Wallet) {
      self.wallets = wallets
      self.activeWallet = activeWallet
    }
  }
  
  let repositoriesAssembly: RepositoriesAssembly
  public let walletAssembly: WalletAssembly
  public let walletUpdateAssembly: WalletsUpdateAssembly
  let servicesAssembly: ServicesAssembly
  public let storesAssembly: StoresAssembly
  public let formattersAssembly: FormattersAssembly
  let configurationAssembly: ConfigurationAssembly
  public let passcodeAssembly: PasscodeAssembly
  public let tonConnectAssembly: TonConnectAssembly
  let apiAssembly: APIAssembly
  let loadersAssembly: LoadersAssembly
  
  init(repositoriesAssembly: RepositoriesAssembly,
       walletAssembly: WalletAssembly,
       walletUpdateAssembly: WalletsUpdateAssembly,
       servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       formattersAssembly: FormattersAssembly,
       configurationAssembly: ConfigurationAssembly,
       passcodeAssembly: PasscodeAssembly,
       tonConnectAssembly: TonConnectAssembly,
       apiAssembly: APIAssembly,
       loadersAssembly: LoadersAssembly) {
    self.repositoriesAssembly = repositoriesAssembly
    self.walletAssembly = walletAssembly
    self.walletUpdateAssembly = walletUpdateAssembly
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.formattersAssembly = formattersAssembly
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
      walletsStore: walletAssembly.walletStore,
      accountNFTService: servicesAssembly.accountNftService(),
      backgroundUpdateStore: storesAssembly.backgroundUpdateStore,
      tonConnectEventsStore: tonConnectAssembly.tonConnectEventsStore,
      knownAccountsStore: storesAssembly.knownAccountsStore,
      balanceStore: storesAssembly.balanceStore,
      dnsService: servicesAssembly.dnsService(),
      tonConnectService: tonConnectAssembly.tonConnectService(),
      deeplinkParser: DefaultDeeplinkParser(
        parsers: [
          TonkeeperDeeplinkParser(),
          TonConnectDeeplinkParser(),
          TonDeeplinkParser(),
        ]
      ),
      apiProvider: apiAssembly.apiProvider
    )
  }
  
  public func walletMainController() -> WalletMainController {
    WalletMainController(
      walletsStore: walletAssembly.walletStore,
      walletBalanceLoader: loadersAssembly.walletBalanceLoader,
      nftsStore: storesAssembly.nftsStore,
      nftsLoader: loadersAssembly.nftsLoader,
      tonRatesLoader: loadersAssembly.tonRatesLoader,
      currencyStore: storesAssembly.currencyStore,
      backgroundUpdateStore: storesAssembly.backgroundUpdateStore
    )
  }
  
  public func walletStoreWalletListController() -> WalletListController {
    let configurator = WalletStoreWalletListControllerConfigurator(
      walletsStore: walletAssembly.walletStore,
      walletsStoreUpdate: walletUpdateAssembly.walletsStoreUpdate
    )
    return WalletListController(
      walletsStore: walletAssembly.walletStore,
      walletTotalBalanceStore: storesAssembly.walletTotalBalanceStore(walletsStore: walletAssembly.walletStore),
      currencyStore: storesAssembly.currencyStore,
      configurator: configurator,
      walletListMapper: walletListMapper
    )
  }
  
  public func walletSelectWalletLisController(selectedWallet: Wallet, 
                                              didSelectWallet: ((Wallet) -> Void)?) -> WalletListController {
    let configurator = WalletSelectWalletListControllerConfigurator(
      selectedWallet: selectedWallet,
      walletsStore: walletAssembly.walletStore
    )
    configurator.didSelectWallet = didSelectWallet
    return WalletListController(
      walletsStore: walletAssembly.walletStore,
      walletTotalBalanceStore: storesAssembly.walletTotalBalanceStore(walletsStore: walletAssembly.walletStore),
      currencyStore: storesAssembly.currencyStore,
      configurator: configurator,
      walletListMapper: walletListMapper
    )
  }
  
  public func walletBalanceController() -> WalletBalanceController {
    WalletBalanceController(
      walletsStore: walletAssembly.walletStore,
      walletBalanceStore: storesAssembly.walletBalanceStore,
      walletTotalBalanceStore: storesAssembly.walletTotalBalanceStore(walletsStore: walletAssembly.walletStore),
      tonRatesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      setupStore: storesAssembly.setupStore,
      securityStore: storesAssembly.securityStore,
      backgroundUpdateStore: storesAssembly.backgroundUpdateStore,
      walletBalanceMapper: walletBalanceMapper
    )
  }
  
  public var settingsController: SettingsController {
    SettingsController(
      walletsStore: walletAssembly.walletStore,
      updateStore: walletUpdateAssembly.walletsStoreUpdate,
      currencyStore: storesAssembly.currencyStore,
      configurationStore: configurationAssembly.remoteConfigurationStore
    )
  }
  
  public func historyController() -> HistoryController {
    HistoryController(walletsStore: walletAssembly.walletStore,
                      backgroundUpdateStore: storesAssembly.backgroundUpdateStore)
  }
  
  public func historyListController(wallet: Wallet) -> HistoryListController {
    let loader = HistoryListAllEventsLoader(
      historyService: servicesAssembly.historyService()
    )
    let paginator = HistoryListPaginator(
      wallet: wallet,
      loader: loader,
      nftService: servicesAssembly.nftService(),
      historyListMapper: historyListMapper,
      dateFormatter: formattersAssembly.dateFormatter
    )
    return HistoryListController(
      walletsStore: walletAssembly.walletStore,
      paginator: paginator,
      backgroundUpdateStore: storesAssembly.backgroundUpdateStore)
  }
  
  public func tonEventsHistoryListController(wallet: Wallet) -> HistoryListController {
    let loader = HistoryListTonEventsLoader(
      historyService: servicesAssembly.historyService()
    )
    let paginator = HistoryListPaginator(
      wallet: wallet,
      loader: loader,
      nftService: servicesAssembly.nftService(),
      historyListMapper: historyListMapper,
      dateFormatter: formattersAssembly.dateFormatter
    )
    return HistoryListController(
      walletsStore: walletAssembly.walletStore,
      paginator: paginator,
      backgroundUpdateStore: storesAssembly.backgroundUpdateStore)
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
      historyListMapper: historyListMapper,
      dateFormatter: formattersAssembly.dateFormatter
    )
    return HistoryListController(
      walletsStore: walletAssembly.walletStore,
      paginator: paginator,
      backgroundUpdateStore: storesAssembly.backgroundUpdateStore)
  }
  
  public func tonTokenDetailsController() -> TokenDetailsController {
    let configurator = TonTokenDetailsControllerConfigurator(
      mapper: tokenDetailsMapper
    )
    return TokenDetailsController(
      configurator: configurator,
      walletsStore: walletAssembly.walletStore,
      walletBalanceStore: storesAssembly.walletBalanceStore,
      currencyStore: storesAssembly.currencyStore,
      tonRatesStore: storesAssembly.tonRatesStore
    )
  }
  
  public func jettonTokenDetailsController(jettonItem: JettonItem) -> TokenDetailsController {
    let configurator = JettonTokenDetailsControllerConfigurator(
      jettonItem: jettonItem,
      mapper: tokenDetailsMapper
    )
    return TokenDetailsController(
      configurator: configurator,
      walletsStore: walletAssembly.walletStore,
      walletBalanceStore: storesAssembly.walletBalanceStore,
      currencyStore: storesAssembly.currencyStore,
      tonRatesStore: storesAssembly.tonRatesStore
    )
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
  
  public func receiveController(token: Token) -> ReceiveController {
    ReceiveController(
      token: token,
      walletsStore: walletAssembly.walletStore,
      deeplinkGenerator: DeeplinkGenerator()
    )
  }
  
  public func historyEventDetailsController(event: AccountEventDetailsEvent) -> HistoryEventDetailsController {
    HistoryEventDetailsController(
      event: event,
      amountMapper: AmountHistoryListEventAmountMapper(amountFormatter: formattersAssembly.amountFormatter),
      tonRatesStore: storesAssembly.tonRatesStore,
      walletsStore: walletAssembly.walletStore,
      currencyStore: storesAssembly.currencyStore,
      nftService: servicesAssembly.nftService()
    )
  }
  
  public func collectiblesController() -> CollectiblesController {
    CollectiblesController(
      walletsStore: walletAssembly.walletStore,
      backgroundUpdateStore: storesAssembly.backgroundUpdateStore,
      nftsStore: storesAssembly.nftsStore
    )
  }
  
  public func collectiblesListController(wallet: Wallet) -> CollectiblesListController {
    CollectiblesListController(
      wallet: wallet,
      nftsListPaginator: NftsListPaginator(
        wallet: wallet,
        accountNftsService: servicesAssembly.accountNftService()
      ),
      nftsStore: storesAssembly.nftsStore
    )
  }
  
  public func collectibleDetailsController(nft: NFT) -> CollectibleDetailsController {
    CollectibleDetailsController(
      nft: nft,
      walletsStore: walletAssembly.walletStore,
      nftService: servicesAssembly.nftService(),
      dnsService: servicesAssembly.dnsService(),
      collectibleDetailsMapper: CollectibleDetailsMapper(dateFormatter: formattersAssembly.dateFormatter)
    )
  }
  
  public func recoveryPhraseController(wallet: Wallet) -> RecoveryPhraseController {
    RecoveryPhraseController(
      wallet: wallet,
      mnemonicRepository: repositoriesAssembly.mnemonicRepository()
    )
  }
  
  public func backupController(wallet: Wallet) -> BackupController {
    BackupController(
      wallet: wallet,
      backupStore: storesAssembly.backupStore,
      walletsStore: walletAssembly.walletStore,
      dateFormatter: formattersAssembly.dateFormatter
    )
  }
  
  public func settingsSecurityController() -> SettingsSecurityController {
    SettingsSecurityController(
      securityStore: storesAssembly.securityStore
    )
  }
  
  public func tonConnectConnectController(parameters: TonConnectParameters,
                                          manifest: TonConnectManifest) -> TonConnectConnectController {
    TonConnectConnectController(
      parameters: parameters,
      manifest: manifest,
      walletsStore: walletAssembly.walletStore,
      tonConnectAppsStore: tonConnectAssembly.tonConnectAppsStore
    )
  }
  
  public func sendController(sendItem: SendItem, recipient: Recipient? = nil) -> SendController {
    SendController(
      sendItem: sendItem,
      recipient: recipient,
      walletsStore: walletAssembly.walletStore,
      balanceStore: storesAssembly.balanceStore,
      knownAccountsStore: storesAssembly.knownAccountsStore,
      dnsService: servicesAssembly.dnsService(),
      amountFormatter: formattersAssembly.amountFormatter
    )
  }
  
  public func sendV3Controller() -> SendV3Controller {
    SendV3Controller(
      walletsStore: walletAssembly.walletStore,
      walletBalanceStore: storesAssembly.walletBalanceStore,
      knownAccountsStore: storesAssembly.knownAccountsStore,
      dnsService: servicesAssembly.dnsService(),
      tonRatesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      amountFormatter: formattersAssembly.amountFormatter
    )
  }

  public func swapController() -> SwapController {
    SwapController(
      walletsStore: walletAssembly.walletStore,
      walletBalanceStore: storesAssembly.walletBalanceStore,
      ratesService: servicesAssembly.ratesService(),
      amountFormatter: formattersAssembly.amountFormatterV2, 
      currencyStore: storesAssembly.currencyStore
    )
  }
  
  public func sendRecipientController(recipient: Recipient?) -> SendRecipientController {
    SendRecipientController(
      recipient: recipient,
      knownAccountsStore: storesAssembly.knownAccountsStore,
      dnsService: servicesAssembly.dnsService()
    )
  }
  
  public func sendAmountController(token: Token,
                                   tokenAmount: BigUInt,
                                   wallet: Wallet) -> SendAmountController {
    SendAmountController(
      token: token,
      tokenAmount: tokenAmount,
      wallet: wallet,
      balanceStore: storesAssembly.balanceStore,
      ratesStore: storesAssembly.ratesStore,
      currencyStore: storesAssembly.currencyStore,
      rateConverter: RateConverter(),
      amountFormatter: formattersAssembly.amountFormatter
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
      blockchainService: servicesAssembly.blockchainService(),
      balanceStore: storesAssembly.balanceStore,
      ratesStore: storesAssembly.ratesStore,
      currencyStore: storesAssembly.currencyStore,
      mnemonicRepository: repositoriesAssembly.mnemonicRepository(),
      amountFormatter: formattersAssembly.amountFormatter
    )
  }
  
  public func tokenPickerController(wallet: Wallet, selectedToken: Token) -> TokenPickerController {
    TokenPickerController(
      wallet: wallet,
      selectedToken: selectedToken,
      walletBalanceStore: storesAssembly.walletBalanceStore,
      amountFormatter: formattersAssembly.amountFormatter
    )
  }

  public func swapAvailableTokenController() -> SwapAvailableTokenController {
    SwapAvailableTokenController(
      // Why not to put activeWallet here?
      wallet: walletAssembly.walletStore.activeWallet,
      jettonService: servicesAssembly.jettonsService(),
      balanceService: servicesAssembly.balanceService(),
      ratesStore: storesAssembly.ratesStore,
      tonRatesStore: storesAssembly.tonRatesStore,
      swapAvailableTokenMapper: swapAvailableTokenMapper,
      currencyStore: storesAssembly.currencyStore,
      amountFormatter: formattersAssembly.amountFormatter
    )
  }
  
  public func buyListController(wallet: Wallet,
                                isMarketRegionPickerAvailable: @escaping () async -> Bool) -> BuyListController {
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
}

private extension MainAssembly {
  func walletListController(configurator: WalletStoreWalletListControllerConfigurator) -> WalletListController {
    return WalletListController(
      walletsStore: walletAssembly.walletStore,
      walletTotalBalanceStore: storesAssembly.walletTotalBalanceStore(walletsStore: walletAssembly.walletStore),
      currencyStore: storesAssembly.currencyStore,
      configurator: configurator,
      walletListMapper: walletListMapper
    )
  }
  
  var walletBalanceMapper: WalletBalanceMapper {
    WalletBalanceMapper(
      amountFormatter: formattersAssembly.amountFormatter,
      decimalAmountFormatter: formattersAssembly.decimalAmountFormatter,
      rateConverter: RateConverter(),
      dateFormatter: formattersAssembly.dateFormatter)
  }
  
  var walletListMapper: WalletListMapper {
    WalletListMapper(
      amountFormatter: formattersAssembly.amountFormatter,
      decimalAmountFormatter: formattersAssembly.decimalAmountFormatter,
      rateConverter: RateConverter() // why this one is initialised and other reused?
    )
  }

  var swapAvailableTokenMapper: SwapAvailableTokenMapper {
    SwapAvailableTokenMapper(
      amountFormatter: formattersAssembly.amountFormatter,
      decimalAmountFormatter: formattersAssembly.decimalAmountFormatter,
      rateConverter: RateConverter(),
      dateFormatter: formattersAssembly.dateFormatter
    )
  }
  
  var historyListMapper: HistoryListMapper {
    HistoryListMapper(
      dateFormatter: formattersAssembly.dateFormatter,
      amountFormatter: formattersAssembly.amountFormatter,
      amountMapper: SignedAmountHistoryListEventAmountMapper(
        amountAccountHistoryListEventAmountMapper: AmountHistoryListEventAmountMapper(
          amountFormatter: formattersAssembly.amountFormatter
        )
      )
    )
  }
  
  var tokenDetailsMapper: TokenDetailsMapper {
    TokenDetailsMapper(
      amountFormatter: formattersAssembly.amountFormatter,
      rateConverter: RateConverter()
    )
  }
}
