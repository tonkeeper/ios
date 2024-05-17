import Foundation
import TonAPI
import BigInt

struct TonConnectConfirmationMapper {
  private let historyListMapper: HistoryListMapper
  private let amountFormatter: AmountFormatter
  
  init(historyListMapper: HistoryListMapper,
       amountFormatter: AmountFormatter) {
    self.historyListMapper = historyListMapper
    self.amountFormatter = amountFormatter
  }
  
  func mapTransactionInfo(_ info: Components.Schemas.MessageConsequences,
                          tonRates: Rates.Rate?,
                          currency: Currency,
                          nftsCollection: NFTsCollection, 
                          wallet: Wallet) throws -> TonConnectConfirmationController.Model {
    let descriptionProvider = TonConnectConfirmationAccountEventRightTopDescriptionProvider(
      rates: tonRates,
      currency: currency,
      formatter: amountFormatter
    )
    
    let eventModel = historyListMapper
      .mapHistoryEvent(
        try AccountEvent(accountEvent: info.event),
        eventDate: Date(),
        nftsCollection: nftsCollection,
        accountEventRightTopDescriptionProvider: descriptionProvider,
        isTestnet: wallet.isTestnet
      )

    var feeFormatted = "\(String.Symbol.almostEqual)\(String.Symbol.shortSpace)"
    + amountFormatter.formatAmount(
      BigUInt(integerLiteral: UInt64(abs(info.event.extra))),
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
    
    return TonConnectConfirmationController.Model(
      event: eventModel,
      fee: feeFormatted,
      walletName: wallet.metaData.emoji + wallet.metaData.label
    )
  }
}
