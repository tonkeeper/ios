import Foundation
import TonSwift
import BigInt

let tUrl = URL(string: "https://cache.tonapi.io/imgproxy/GjhSro_E6Qxod2SDQeDhJA_F3yARNomyZFKeKw8TVOU/rs:fill:200:200:1/g:no/aHR0cHM6Ly90b25zdGFrZXJzLmNvbS9qZXR0b24vbG9nby5zdmc.webp")


public final class StakingConfirmationController {
  
  public var didUpdateModel: ((StakingConfirmationModel) -> Void)?
  public let operation: StakingOperation
  
  private let wallet: Wallet
  private let balanceStore: BalanceStore
  private let ratesStore: RatesStore
  private let currencyStore: CurrencyStore
  private let mnemonicRepository: WalletMnemonicRepository
  private let amountFormatter: AmountFormatter
  
  init(
    operation: StakingOperation,
    wallet: Wallet,
    balanceStore: BalanceStore,
    ratesStore: RatesStore,
    currencyStore: CurrencyStore,
    mnemonicRepository: WalletMnemonicRepository,
    amountFormatter: AmountFormatter
  ) {
    self.operation = operation
    self.wallet = wallet
    self.balanceStore = balanceStore
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.mnemonicRepository = mnemonicRepository
    self.amountFormatter = amountFormatter
  }
  
  public func start() async {
    let model = await buildModel(fee: .loading, feeConverted: .value(nil))
    await MainActor.run {
      didUpdateModel?(model)
    }
  }
}


// MARK: - Private methods

private extension StakingConfirmationController {
  func buildModel(
    fee: LoadableModelItem<String>,
    feeConverted: LoadableModelItem<String?>
  ) async -> StakingConfirmationModel {
    let amount = BigUInt(integerLiteral: 1_000_000_000)
    
    var formattedAmount: String?
    var formattedConvertedAmount: String?
    
    formattedAmount = amountFormatter.formatAmount(
      amount,
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits
    )
    
    let rates = ratesStore.getRates(jettons: []).ton
    let currency = await currencyStore.getActiveCurrency()
    if let rates = rates.first(where: { $0.currency == currency }) {
      let rateConverter = RateConverter()
      let converted = rateConverter.convert(
        amount: amount,
        amountFractionLength: TonInfo.fractionDigits,
        rate: rates
      )
      
      formattedConvertedAmount = amountFormatter.formatAmount(
        converted.amount,
        fractionDigits: converted.fractionLength,
        maximumFractionDigits: 2,
        currency: currency
      )
    }
    
    return  StakingConfirmationModel(
      provider: "Tonstakers",
      providerImage: tUrl,
      wallet: wallet.model.emojiLabel,
      apyPercent: "≈ 5.01%",
      amount: formattedAmount,
      amountConverted: .value(formattedConvertedAmount),
      fee: fee,
      feeConverted: feeConverted
    )
  }
}
