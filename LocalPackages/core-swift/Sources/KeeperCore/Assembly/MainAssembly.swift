import Foundation
import TonSwift
import BigInt
import URKit

public final class MainAssembly {
  public let appInfoProvider: AppInfoProvider
  public let repositoriesAssembly: RepositoriesAssembly
  public let walletUpdateAssembly: WalletsUpdateAssembly
  public let servicesAssembly: ServicesAssembly
  public let storesAssembly: StoresAssembly
  public let coreAssembly: CoreAssembly
  public let formattersAssembly: FormattersAssembly
  public let mappersAssembly: MappersAssembly
  public let configurationAssembly: ConfigurationAssembly
  public let buySellAssembly: BuySellAssembly
  public let knownAccountsAssembly: KnownAccountsAssembly
  public let batteryAssembly: BatteryAssembly
  public let tonConnectAssembly: TonConnectAssembly
  public let loadersAssembly: LoadersAssembly
  public let backgroundUpdateAssembly: BackgroundUpdateAssembly
  public let apiAssembly: APIAssembly
  public let tonkeeperAPIAssembly: TonkeeperAPIAssembly
  public let rnAssembly: RNAssembly
  public let secureAssembly: SecureAssembly
  public let transferAssembly: TransferAssembly
  public let transactionsManagementAssembly: TransactionsManagementAssembly
  public let tronUSDTAssembly: TronUSDTAssembly
  
  init(appInfoProvider: AppInfoProvider,
       repositoriesAssembly: RepositoriesAssembly,
       walletUpdateAssembly: WalletsUpdateAssembly,
       servicesAssembly: ServicesAssembly,
       storesAssembly: StoresAssembly,
       coreAssembly: CoreAssembly,
       formattersAssembly: FormattersAssembly,
       mappersAssembly: MappersAssembly,
       configurationAssembly: ConfigurationAssembly,
       buySellAssembly: BuySellAssembly,
       knownAccountsAssembly: KnownAccountsAssembly,
       batteryAssembly: BatteryAssembly,
       tonConnectAssembly: TonConnectAssembly,
       apiAssembly: APIAssembly,
       tonkeeperAPIAssembly: TonkeeperAPIAssembly,
       loadersAssembly: LoadersAssembly,
       backgroundUpdateAssembly: BackgroundUpdateAssembly,
       secureAssembly: SecureAssembly,
       rnAssembly: RNAssembly,
       transactionsManagementAssembly: TransactionsManagementAssembly,
       tronUSDTAssembly: TronUSDTAssembly) {
    self.appInfoProvider = appInfoProvider
    self.repositoriesAssembly = repositoriesAssembly
    self.walletUpdateAssembly = walletUpdateAssembly
    self.servicesAssembly = servicesAssembly
    self.storesAssembly = storesAssembly
    self.coreAssembly = coreAssembly
    self.formattersAssembly = formattersAssembly
    self.mappersAssembly = mappersAssembly
    self.configurationAssembly = configurationAssembly
    self.buySellAssembly = buySellAssembly
    self.knownAccountsAssembly = knownAccountsAssembly
    self.batteryAssembly = batteryAssembly
    self.tonConnectAssembly = tonConnectAssembly
    self.apiAssembly = apiAssembly
    self.tonkeeperAPIAssembly = tonkeeperAPIAssembly
    self.loadersAssembly = loadersAssembly
    self.backgroundUpdateAssembly = backgroundUpdateAssembly
    self.secureAssembly = secureAssembly
    self.rnAssembly = rnAssembly
    self.transferAssembly = TransferAssembly(
      servicesAssembly: servicesAssembly,
      batteryAssembly: batteryAssembly,
      configurationAssembly: configurationAssembly,
      repositoriesAssembly: repositoriesAssembly
    )
    self.transactionsManagementAssembly = transactionsManagementAssembly
    self.tronUSDTAssembly = tronUSDTAssembly
  }
  
  public func scannerAssembly() -> ScannerAssembly {
    ScannerAssembly()
  }
  
  public func mainController() -> MainController {
    MainController(
      backgroundUpdate: backgroundUpdateAssembly.backgroundUpdate,
      tonConnectEventsStore: tonConnectAssembly.tonConnectEventsStore,
      tonConnectService: tonConnectAssembly.tonConnectService(),
      deeplinkParser: DeeplinkParser(),
      balanceLoader: loadersAssembly.balanceLoader,
      internalNotificationsLoader: loadersAssembly.internalNotificationsLoader
    )
  }

  public var walletDeleteController: WalletDeleteController {
    WalletDeleteController(walletStore: storesAssembly.walletsStore,
                           keeperInfoStore: storesAssembly.keeperInfoStore,
                           mnemonicsRepository: secureAssembly.mnemonicsRepository())
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
  
  public func sendV3Controller(wallet: Wallet) -> SendV3Controller {
    SendV3Controller(
      wallet: wallet,
      balanceStore: storesAssembly.convertedBalanceStore,
      dnsService: servicesAssembly.dnsService(),
      tonRatesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      recipientResolver: loadersAssembly.recipientResolver(),
      amountFormatter: formattersAssembly.amountFormatter
    )
  }
  
  public func sendConfirmationController(wallet: Wallet,
                                         recipient: TonRecipient,
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
  
  public func jettonTransferTransactionConfirmationController(wallet: Wallet,
                                                              recipient: TonRecipient,
                                                              jettonItem: JettonItem,
                                                              amount: BigUInt,
                                                              comment: String?) -> TransactionConfirmationController {
    JettonTransferTransactionConfirmationController(
      wallet: wallet,
      recipient: recipient,
      jettonItem: jettonItem,
      amount: amount,
      comment: comment,
      sendService: servicesAssembly.sendService(),
      blockchainService: servicesAssembly.blockchainService(),
      ratesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      transferService: transferAssembly.transferService(),
      ratesService: servicesAssembly.ratesService(),
      balanceService: servicesAssembly.balanceService(),
      settingsRepository: repositoriesAssembly.settingsRepository(),
      batteryCalculation: batteryAssembly.batteryCalculation
    )
  }
  
  public func tonTransferTransactionConfirmationController(wallet: Wallet,
                                                           recipient: TonRecipient,
                                                           amount: BigUInt,
                                                           comment: String?,
                                                           isMaxAmount: Bool) -> TransactionConfirmationController {
    TonTransferTransactionConfirmationController(
      wallet: wallet,
      recipient: recipient,
      amount: amount,
      comment: comment,
      isMaxAmount: isMaxAmount,
      sendService: servicesAssembly.sendService(),
      blockchainService: servicesAssembly.blockchainService(),
      ratesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      transferService: transferAssembly.transferService(),
      ratesService: servicesAssembly.ratesService()
    )
  }
  
  public func nftTransferTransactionConfirmationController(wallet: Wallet,
                                                           recipient: TonRecipient,
                                                           nft: NFT,
                                                           comment: String?) -> TransactionConfirmationController {
    NFTTransferTransactionConfirmationController(
      wallet: wallet,
      recipient: recipient,
      nft: nft,
      comment: comment,
      sendService: servicesAssembly.sendService(),
      blockchainService: servicesAssembly.blockchainService(),
      ratesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      transferService: transferAssembly.transferService(),
      ratesService: servicesAssembly.ratesService(),
      settingsRepository: repositoriesAssembly.settingsRepository(),
      batteryCalculation: batteryAssembly.batteryCalculation
    )
  }
  
  public func tronUSDTTransferTransactionConfirmationController(wallet: Wallet,
                                                                recipient: TronRecipient,
                                                                amount: BigUInt) -> TronUSDTTransactionConfirmationController {
    TronUSDTTransactionConfirmationController(
      wallet: wallet,
      recipient: recipient,
      amount: amount,
      tronAPI: tronUSDTAssembly.api,
      tonProofService: servicesAssembly.tonProofTokenService()
    )
  }
  
  public func stakingWithdrawTransactionConfirmationController(wallet: Wallet,
                                                               stakingPool: StackingPoolInfo,
                                                               amount: BigUInt,
                                                               isCollect: Bool) -> TransactionConfirmationController {
    return StakingWithdrawTransactionConfirmationController(
      wallet: wallet,
      stakingPool: stakingPool,
      amount: amount,
      isCollect: isCollect,
      sendService: servicesAssembly.sendService(),
      blockchainService: servicesAssembly.blockchainService(),
      balanceStore: storesAssembly.balanceStore,
      ratesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore
    )
  }
  
  public func stakingDepositTransactionConfirmationController(wallet: Wallet,
                                                               stakingPool: StackingPoolInfo,
                                                               amount: BigUInt,
                                                               isCollect: Bool) -> TransactionConfirmationController {
    return StakingDepositTransactionConfirmationController(
      wallet: wallet,
      stakingPool: stakingPool,
      amount: amount,
      isCollect: isCollect,
      sendService: servicesAssembly.sendService(),
      blockchainService: servicesAssembly.blockchainService(),
      tonBalanceService: servicesAssembly.tonBalanceService(),
      ratesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore
    )
  }
  
  public func signerSignController(url: URL, wallet: Wallet) -> SignerSignController {
    SignerSignController(url: url, wallet: wallet)
  }
  
  public func keystoneSignController(transaction: UR, wallet: Wallet) -> KeystoneSignController {
    KeystoneSignController(transaction: transaction, wallet: wallet)
  }
  
  public func browserExploreController() -> BrowserExploreController {
    BrowserExploreController(popularAppsService: servicesAssembly.popularAppsService())
  }
  
  public func linkDNSController(wallet: Wallet, nft: NFT) -> LinkDNSController {
    LinkDNSController(
      wallet: wallet,
      nft: nft,
      sendService: servicesAssembly.sendService()
    )
  }
  
  public func decryptCommentController() -> DecryptCommentController {
    DecryptCommentController(
      encryptedCommentService: servicesAssembly.encryptedCommentService(),
      decryptedCommentStore: storesAssembly.decryptedCommentStore
    )
  }
}
