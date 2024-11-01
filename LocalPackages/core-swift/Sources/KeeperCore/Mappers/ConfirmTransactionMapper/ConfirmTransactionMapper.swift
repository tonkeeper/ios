import Foundation
import TonAPI
import BigInt
import TKLocalize

struct ConfirmTransactionMapper {

  private let nftService: NFTService
  private let accountEventMapper: AccountEventMapper
  private let amountFormatter: AmountFormatter
  private let decimalAmountFormatter: DecimalAmountFormatter

  init(nftService: NFTService,
       accountEventMapper: AccountEventMapper,
       amountFormatter: AmountFormatter,
       decimalAmountFormatter: DecimalAmountFormatter
  ) {
    self.nftService = nftService
    self.accountEventMapper = accountEventMapper
    self.amountFormatter = amountFormatter
    self.decimalAmountFormatter = decimalAmountFormatter
  }
  
  func mapTransactionInfo(
    _ info: TonAPI.MessageConsequences,
    tonRates: Rates.Rate?,
    currency: Currency,
    totalBalanceStore: TotalBalanceStore,
    nftsCollection: NFTsCollection,
    wallet: Wallet
  ) throws -> ConfirmTransactionModel {
    
    let descriptionProvider = TonConnectConfirmationAccountEventRightTopDescriptionProvider(
      rates: tonRates,
      currency: currency,
      formatter: amountFormatter
    )
    
    let eventModel = accountEventMapper
      .mapEvent(
        try AccountEvent(accountEvent: info.event),
        eventDate: Date(),
        accountEventRightTopDescriptionProvider: descriptionProvider,
        isTestnet: wallet.isTestnet,
        nftProvider: { address in
          try? self.nftService.getNFT(address: address, isTestnet: wallet.isTestnet)
        }, decryptedCommentProvider: { _ in return nil }
      )

    let fee = Int64(abs(info.event.extra))
    var feeFormatted = "\(String.Symbol.almostEqual)\(String.Symbol.shortSpace)"
    + amountFormatter.formatAmount(
      BigUInt(fee),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits,
      currency: .TON)
    
    if let tonRates = tonRates {
      let rateConverter = RateConverter()
      let feeConverted = rateConverter.convert(
        amount: abs(info.event.extra),
        amountFractionLength: TonInfo.fractionDigits,
        rate: tonRates
      )
      let formattedFeeConverted = amountFormatter.formatAmount(
        feeConverted.amount,
        fractionDigits: feeConverted.fractionLength,
        maximumFractionDigits: 2,
        currency: currency)
      feeFormatted += "\(String.Symbol.shortSpace)\(String.Symbol.middleDot)\(String.Symbol.shortSpace)"
      + formattedFeeConverted
    }

    let formattedRisk = composeFormattedRisk(
      transactionInfo: info,
      fee: fee,
      tonRates: tonRates,
      totalBalanceStore: totalBalanceStore,
      currency: currency,
      wallet: wallet
    )
    return ConfirmTransactionModel(
      event: eventModel,
      formattedFee: feeFormatted,
      wallet: wallet,
      formattedRisk: formattedRisk
    )
  }

  private func composeFormattedRisk(
    transactionInfo: TonAPI.MessageConsequences,
    fee: Int64,
    tonRates: Rates.Rate?,
    totalBalanceStore: TotalBalanceStore,
    currency: Currency,
    wallet: Wallet
  ) -> ConfirmTransactionModel.Risk? {

    guard let totalBalanceState = totalBalanceStore.state[wallet],
          let totalBalance = totalBalanceState.totalBalance,
          let rate = tonRates
    else {
      return nil
    }

    let tonRisk = transactionInfo.risk.ton
    let totalRisk = tonRisk + fee

    let convertedTonRisk = RateConverter().convertToDecimal(
      amount: BigUInt(totalRisk),
      amountFractionLength: TonInfo.fractionDigits,
      rate: rate
    )
    let riskLowMark = totalBalance.amount * 0.2
    let isRisk = convertedTonRisk >= riskLowMark
    let total = decimalAmountFormatter.format(
      amount: convertedTonRisk,
      maximumFractionDigits: 2,
      currency: currency
    )

    let title: String
    let caption: String
    if transactionInfo.risk.nfts.isEmpty {
      title = TKLocales.ConfirmSend.Risk.total(total)
      caption = TKLocales.ConfirmSend.Risk.captionWithoutNft
    } else {
      title = TKLocales.ConfirmSend.Risk.totalNft(total, transactionInfo.risk.nfts.count)
      caption = TKLocales.ConfirmSend.Risk.nftCaption
    }

    return .init(formattedTotal: total, title: title, caption: caption, isRisk: isRisk)
  }
}
