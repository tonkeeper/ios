import UIKit
import TKUIKit
import UIComponents
import Mapping
import KeeperCore
import BigInt
import TKLocalize

public struct SignRawConfirmationModel {
  struct Risk {
    let total: String
    let title: String
    let caption: String
    let isRisk: Bool
  }

  public typealias TransactionTokenInfo = (token: Token, availableBalance: BigUInt)
  public struct ProvisionModel {
    public let fee: UInt64
    public let tonBalance: UInt64
    public let requiredAmount: UInt64
    public let token: TransactionTokenInfo
  }

  let contentModel: AccountEventCellContentView.Model
  let risk: Risk?
}

struct SignRawConfirmationMapper {
  private let nftService: NFTService
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let totalBalanceStore: TotalBalanceStore
  private let balanceStore: BalanceStore
  private let nftManagmentStore: WalletNFTsManagementStore
  private let accountEventMapper: Mapping.AccountEventMapper
  private let accountEventModelMapper: Mapping.AccountEventModelMapper
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let amountFormatter: AmountFormatter
  
  public init(nftService: NFTService,
              tonRatesStore: TonRatesStore,
              currencyStore: CurrencyStore,
              totalBalanceStore: TotalBalanceStore,
              balanceStore: BalanceStore,
              nftManagmentStore: WalletNFTsManagementStore,
              accountEventMapper: Mapping.AccountEventMapper,
              accountEventModelMapper: Mapping.AccountEventModelMapper,
              decimalAmountFormatter: DecimalAmountFormatter,
              amountFormatter: AmountFormatter) {
    self.nftService = nftService
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.totalBalanceStore = totalBalanceStore
    self.balanceStore = balanceStore
    self.nftManagmentStore = nftManagmentStore
    self.accountEventMapper = accountEventMapper
    self.accountEventModelMapper = accountEventModelMapper
    self.decimalAmountFormatter = decimalAmountFormatter
    self.amountFormatter = amountFormatter
  }
  
  func mapEmulationResult(emulation: SignRawEmulation, wallet: Wallet) -> SignRawConfirmationModel {
    SignRawConfirmationModel(
      contentModel: mapSuccessEmulationResult(signRawEmulation: emulation, wallet: wallet),
      risk: mapRisk(emulation: emulation, wallet: wallet)
    )
  }
  
  func mapSuccessEmulationResult(signRawEmulation: SignRawEmulation, wallet: Wallet) -> AccountEventCellContentView.Model {
    let currency = currencyStore.getState()
    let tonRate = tonRatesStore.getState().first(where: { $0.currency == currency })
    
    let descriptionProvider = SignRawConfirmationAccountEventRightTopDescriptionProvider(
      rates: tonRate,
      currency: currency,
      formatter: amountFormatter
    )
    
    let eventModel = accountEventMapper.mapEvent(
      signRawEmulation.event,
      nftManagmentStore: nftManagmentStore,
      eventDate: Date(),
      accountEventRightTopDescriptionProvider: descriptionProvider,
      isTestnet: wallet.isTestnet,
      nftProvider: { address in
        try? self.nftService.getNFT(address: address, isTestnet: wallet.isTestnet)
      },
      decryptedCommentProvider: { _ in return nil }
    )
    
    let feeFormatted = "\(String.Symbol.almostEqual)\(String.Symbol.shortSpace)"
    + amountFormatter.formatAmount(
      BigUInt(signRawEmulation.fee),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      currency: .TON)
    var feeConverted: String?
    if let tonRate {
      let converted = RateConverter().convertToDecimal(
        amount: BigUInt(signRawEmulation.fee),
        amountFractionLength: TonInfo.fractionDigits,
        rate: tonRate
      )
      feeConverted = decimalAmountFormatter.format(
        amount: converted,
        maximumFractionDigits: 2,
        significantFractionDigits: 2,
        currency: currency
      )
    }
    
    let model = accountEventModelMapper.mapSignRawEventContentConfiguration(
      eventModel,
      fee: feeFormatted,
      feeConverted: feeConverted,
      feeDescription: signRawEmulation.transferType.isBattery ? TKLocales.TransactionConfirmation.battery : nil
    )
    return model
  }
  
  func mapRisk(emulation: SignRawEmulation, wallet: Wallet) -> SignRawConfirmationModel.Risk? {
    let currency = currencyStore.getState()
    guard let totalBalanceState = totalBalanceStore.state[wallet],
          let totalBalance = totalBalanceState.totalBalance,
          let tonRate = tonRatesStore.getState().first(where: { $0.currency == currency })
    else {
      return nil
    }
    
    let tonRisk = emulation.risk.ton
    let totalRisk = tonRisk + emulation.fee
    
    let convertedTonRisk = RateConverter().convertToDecimal(
      amount: BigUInt(totalRisk),
      amountFractionLength: TonInfo.fractionDigits,
      rate: tonRate
    )
    let riskLowMark = totalBalance.amount * emulation.risk.totalAmountTreshold
    let isRisk = convertedTonRisk >= riskLowMark
    let total = decimalAmountFormatter.format(
      amount: convertedTonRisk,
      maximumFractionDigits: 2,
      currency: currency
    )
    
    let title: String
    let caption: String
    if emulation.risk.nftsCount == 0 {
      title = TKLocales.ConfirmSend.Risk.total(total)
      caption = TKLocales.ConfirmSend.Risk.captionWithoutNft
    } else {
      title = TKLocales.ConfirmSend.Risk.totalNft(total, emulation.risk.nftsCount)
      caption = TKLocales.ConfirmSend.Risk.nftCaption
    }
    
    return SignRawConfirmationModel.Risk(
      total: total,
      title: title,
      caption: caption,
      isRisk: isRisk
    )
  }
}


