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
    buyListController: BuyListController,
    currencyRateFormatter: CurrencyToTONFormatter,
    bigIntAmountFormatter: BigIntAmountFormatter
  ) -> MVVMModule<TransactionViewController, TransactionViewModelOutput, Void> {
    let exchangeConverter = ExchangeConfirmationConverter(
      bigIntAmountFormatter: bigIntAmountFormatter,
      rateConverter: RateConverter(),
      rate: buySellItem.rate
    )
    
    let inputValidator = BuySellInputValidator(
      minTonBuyAmount: buySellItem.minTonBuyAmount,
      minTonSellAmount: buySellItem.minTonSellAmount,
      buyListController: buyListController,
      bigIntAmountFormatter: bigIntAmountFormatter
    )
    
    exchangeConverter.setup(transactionAmountModel: transactionModel)
    
    let viewModel = TransactionViewModelImplementation(
      buySellItem: buySellItem,
      transactionModel: transactionModel,
      currency: currency,
      exchangeConverter: exchangeConverter,
      currencyRateFormatter: currencyRateFormatter,
      inputValidator: inputValidator
    )
    
    let viewController = TransactionViewController(viewModel: viewModel)
    
    return MVVMModule(
      view: viewController,
      output: viewModel,
      input: Void()
    )
  }
}
