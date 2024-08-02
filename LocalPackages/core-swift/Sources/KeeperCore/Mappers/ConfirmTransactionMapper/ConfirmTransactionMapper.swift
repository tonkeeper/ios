import Foundation
import TonAPI
import BigInt

struct ConfirmTransactionMapper {
  private let accountEventMapper: AccountEventMapper
  private let amountFormatter: AmountFormatter
  
  init(accountEventMapper: AccountEventMapper,
       amountFormatter: AmountFormatter) {
    self.accountEventMapper = accountEventMapper
    self.amountFormatter = amountFormatter
  }
  
  func mapTransactionInfo(_ info: Components.Schemas.MessageConsequences,
                          tonRates: Rates.Rate?,
                          currency: Currency,
                          nftsCollection: NFTsCollection,
                          wallet: Wallet) throws -> ConfirmTransactionModel {
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
        nftProvider: { _ in nil }
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
    
    return ConfirmTransactionModel(
      event: eventModel,
      fee: feeFormatted,
      wallet: wallet
    )
  }
}
