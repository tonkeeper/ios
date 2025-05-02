import Foundation
import TKLocalize
import KeeperCore
import BigInt
import TronSwift

final class HistoryEventDetailsTronMapper {
  private let wallet: Wallet
  private let amountMapper: AccountEventAmountMapper
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let isTestnet: Bool
  private let configuration: Configuration
  
  private let rateConverter = RateConverter()
  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = "d MMM, HH:mm"
    return formatter
  }()
  
  init(wallet: Wallet,
       amountMapper: AccountEventAmountMapper,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       isTestnet: Bool,
       configuration: Configuration) {
    self.wallet = wallet
    self.amountMapper = amountMapper
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.isTestnet = isTestnet
    self.configuration = configuration
  }
  
  func mapEvent(event: TronTransaction) -> HistoryEventDetailsModel {
    let date = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(event.timestamp)))
    
    let amountType: AccountEventActionAmountMapperActionType
    let dateFormatted: String
    var listItems = [HistoryEventDetailsModel.ListItem]()
    if event.toAccount == wallet.tron?.address {
      amountType = .income
      dateFormatted = TKLocales.EventDetails.receivedOn(date)
      listItems.append(.senderAddress(
        value: event.fromAccount.base58,
        copyValue: event.fromAccount.base58)
      )
    } else {
      amountType = .outcome
      dateFormatted = TKLocales.EventDetails.sentOn(date)
      listItems.append(.recipientAddress(
        value: event.toAccount.base58,
        copyValue: event.toAccount.base58)
      )
    }
    
    let title = amountMapper.mapAmount(
      amount: event.amount,
      fractionDigits: TronSwift.USDT.fractionDigits,
      maximumFractionDigits: TronSwift.USDT.fractionDigits,
      type: amountType,
      symbol: TronSwift.USDT.symbol)
    
    if let batteryCharges = event.batteryCharges {
      listItems.append(.extra(value: "\(batteryCharges) battery charges", isRefund: false, converted: nil))
    }
    
    let detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton = {
      let transaction = TKLocales.EventDetails.transaction.withTextStyle(.label1, color: .Text.primary)
      let hash = String(event.txID.prefix(8)).withTextStyle(.label1, color: .Text.secondary)
      let title = NSMutableAttributedString(attributedString: transaction)
      title.append(hash)
      
      let url = URL(string:"https://tronscan.org/#/transaction/\(event.txID)")!
      let detailsButton = HistoryEventDetailsModel.TransasctionDetailsButton(
        buttonTitle: title,
        url: url,
        browserTitle: "Tronscan",
        hash: event.txID
      )
      return detailsButton
    }()
    
    let fiatPrice: String? = {
      let currency = currencyStore.getState()
      guard let rate = tonRatesStore.getState().usdtRates.first(where: { $0.currency == currency }) else {
        return nil
      }
      let fiat = rateConverter.convert(
        amount: event.amount,
        amountFractionLength: TronSwift.USDT.fractionDigits,
        rate: rate
      )
      return amountMapper.mapAmount(
        amount: fiat.amount,
        fractionDigits: fiat.fractionLength,
        maximumFractionDigits: 2,
        type: .none,
        currency: currency)
    }()

    return HistoryEventDetailsModel(
      headerImage: .transfer(
        TransactionConfirmationHeaderImageItem(
          configuration: TransactionConfirmationHeaderImageItemView.Configuration(
            image: .image(.App.Currency.Size96.usdt),
            corners: .circle,
            badgeImage: .image(.App.Currency.Vector.trc20)
          ),
          bottomSpace: 20
        )
      ),
      title: title,
      date: dateFormatted,
      fiatPrice: fiatPrice,
      status: event.isFailed ? "Failed" : nil,
      isScam: false,
      management: nil,
      listItems: listItems,
      detailsButton: detailsButton
    )
  }
}
