import UIKit
import TKCore
import KeeperCore
import BigInt

struct TransactionAssembly {
  private init() {}
  static func module(
    buySellItem: BuySellItemModel,
    transactionModel: TransactionAmountModel,
    currency: Currency,
    appSettings: AppSettings,
    buyListController: BuyListController,
    currencyRateFormatter: CurrencyToTONFormatter,
    bigIntAmountFormatter: BigIntAmountFormatter
  ) -> MVVMModule<TransactionViewController, TransactionViewModelOutput, Void> {
    let exchangeConverter = ExchangeConfirmationConverter(
      bigIntAmountFormatter: bigIntAmountFormatter,
      rateConverter: RateConverter(),
      rate: buySellItem.rate
    )
    exchangeConverter.setup(amount: transactionModel.amount)
    
    let inputValidator = BuySellInputValidator(
      minTonBuyAmount: buySellItem.minTonBuyAmount,
      minTonSellAmount: buySellItem.minTonSellAmount,
      buyListController: buyListController,
      bigIntAmountFormatter: bigIntAmountFormatter
    )
    
    let viewModel = TransactionViewModelImplementation(
      buySellItem: buySellItem,
      transactionType: transactionModel.type,
      currency: currency,
      exchangeConverter: exchangeConverter,
      currencyRateFormatter: currencyRateFormatter,
      inputValidator: inputValidator,
      appSettings: appSettings
    )
    
    let viewController = TransactionViewController(viewModel: viewModel)
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: Void()
    )
  }
}
