import Foundation
import TonAPI
import BigInt
import TonSwift

public final class SwapAvailableTokenController {

  private let wallet: Wallet
  private let jettonService: JettonService
  private let balanceService: BalanceService
  private let ratesStore: RatesStore
  private let tonRatesStore: TonRatesStore
  private let swapAvailableTokenMapper: SwapAvailableTokenMapper
  private let currencyStore: CurrencyStore
  private let amountFormatter: AmountFormatter

  init(wallet: Wallet,
       jettonService: JettonService,
       balanceService: BalanceService,
       ratesStore: RatesStore,
       tonRatesStore: TonRatesStore,
       swapAvailableTokenMapper: SwapAvailableTokenMapper,
       currencyStore: CurrencyStore,
       amountFormatter: AmountFormatter) {
    self.wallet = wallet
    self.jettonService = jettonService
    self.balanceService = balanceService
    self.ratesStore = ratesStore
    self.tonRatesStore = tonRatesStore
    self.swapAvailableTokenMapper = swapAvailableTokenMapper
    self.currencyStore = currencyStore
    self.amountFormatter = amountFormatter
  }

  public func receiveTokenList() async -> [AvailableTokenModelItem] {
    async let availableJettons = try? jettonService.loadAvailable(wallet: wallet)
    async let walletBalance = try? balanceService.getBalance(wallet: wallet)
    let activeCurrency = await currencyStore.getActiveCurrency()
    var availableTokens = [AvailableTokenModelItem]()
    var alreadyAddedTokens = Set<Address>()
    if let balance = await walletBalance?.balance {
      let rates = ratesStore.getRates(jettons: balance.jettonsBalance.compactMap { $0.item.jettonInfo })
      availableTokens.append(swapAvailableTokenMapper.mapTon(
        balance: balance.tonBalance,
        rates: rates.ton, currency: activeCurrency)
      )

      let tokensOnBalance = swapAvailableTokenMapper.mapJettons(
        jettonsBalance: balance.jettonsBalance,
        jettonsRates: rates.jettonsRates,
        currency: activeCurrency
      )
      tokensOnBalance.forEach {
        if case let .jetton(item) = $0.token {
          alreadyAddedTokens.insert(item.walletAddress)
        }
      }
      availableTokens.append(contentsOf: tokensOnBalance)
    }
//    if let jettons = await availableJettons {
//      availableTokens.append(
//        contentsOf: jettons.compactMap {
//          AvailableTokenModelItem(
//            token: .jetton(.init(jettonInfo: $0, walletAddress: $0.address)),
//            quantity: 0,
//            rates: [:]
//          )
//        }
//      )
//    }
    return availableTokens
  }
}
