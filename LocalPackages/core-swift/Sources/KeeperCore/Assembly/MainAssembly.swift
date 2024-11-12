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
  let apiAssembly: APIAssembly
  public let rnAssembly: RNAssembly
  public let secureAssembly: SecureAssembly
  
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
       loadersAssembly: LoadersAssembly,
       backgroundUpdateAssembly: BackgroundUpdateAssembly,
       secureAssembly: SecureAssembly,
       rnAssembly: RNAssembly) {
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
    self.loadersAssembly = loadersAssembly
    self.backgroundUpdateAssembly = backgroundUpdateAssembly
    self.secureAssembly = secureAssembly
    self.rnAssembly = rnAssembly
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
  
  public func storiesController(pages: [StoriesController.StoryPage]) -> StoriesController {
    StoriesController(
      pages: pages
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
  
  public func jettonTransferTransactionConfirmationController(wallet: Wallet,
                                                              recipient: Recipient,
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
      balanceStore: storesAssembly.balanceStore,
      ratesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      transferTransaction: transferTransaction()
    )
  }
  
  public func tonTransferTransactionConfirmationController(wallet: Wallet,
                                                           recipient: Recipient,
                                                           amount: BigUInt,
                                                           comment: String?) -> TransactionConfirmationController {
    TonTransferTransactionConfirmationController(
      wallet: wallet,
      recipient: recipient,
      amount: amount,
      comment: comment,
      sendService: servicesAssembly.sendService(),
      blockchainService: servicesAssembly.blockchainService(),
      ratesStore: storesAssembly.tonRatesStore,
      currencyStore: storesAssembly.currencyStore,
      transferTransaction: transferTransaction()
    )
  }
  
  public func nftTransferTransactionConfirmationController(wallet: Wallet,
                                                           recipient: Recipient,
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
      transferTransaction: transferTransaction()
    )
  }
  
  func transferTransaction() -> TransferTransaction {
    TransferTransaction(
      tonProofTokenService: servicesAssembly.tonProofTokenService(),
      sendService: servicesAssembly.sendService(),
      batteryService: batteryAssembly.batteryService(),
      balanceStore: storesAssembly.balanceStore,
      accountService: servicesAssembly.accountService(),
      configuration: configurationAssembly.configuration
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
      totalBalanceStore: storesAssembly.totalBalanceStore,
      confirmTransactionMapper: ConfirmTransactionMapper(
        nftService: servicesAssembly.nftService(),
        accountEventMapper: AccountEventMapper(
          dateFormatter: formattersAssembly.dateFormatter,
          amountFormatter: formattersAssembly.amountFormatter,
          amountMapper: PlainAccountEventAmountMapper(amountFormatter: formattersAssembly.amountFormatter)
        ),
        amountFormatter: formattersAssembly.amountFormatter,
        decimalAmountFormatter: formattersAssembly.decimalAmountFormatter
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
  
  public func decryptCommentController() -> DecryptCommentController {
    DecryptCommentController(
      encryptedCommentService: servicesAssembly.encryptedCommentService(),
      decryptedCommentStore: storesAssembly.decryptedCommentStore
    )
  }

  public func NFTScamController(nft: NFT) -> NFTScamController {
    KeeperCore.NFTScamController(configuration: configurationAssembly.configuration, nft: nft)
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
