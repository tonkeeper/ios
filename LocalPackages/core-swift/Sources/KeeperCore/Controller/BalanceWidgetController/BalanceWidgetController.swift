import Foundation
import BigInt

public final class BalanceWidgetController {
  public enum Error: Swift.Error {
    case failedToLoad
    case noWallet
  }
  
  public struct Model {
    public let tonBalance: String
    public let fiatBalance: String
    public let address: String
    
    public init(tonBalance: String, fiatBalance: String, address: String) {
      self.tonBalance = tonBalance
      self.fiatBalance = fiatBalance
      self.address = address
    }
  }
  
  private let walletService: WalletsService
  private let balanceService: BalanceService
  private let ratesService: RatesService
  private let amountFormatter: AmountFormatter
  
  init(walletService: WalletsService, 
       balanceService: BalanceService,
       ratesService: RatesService,
       amountFormatter: AmountFormatter) {
    self.walletService = walletService
    self.balanceService = balanceService
    self.ratesService = ratesService
    self.amountFormatter = amountFormatter
  }
  
  public func loadBalance(walletIdentifier: String?,
                          currency: Currency) async throws -> Model {
    guard let wallets = try? walletService.getWallets(), !wallets.isEmpty else {
      throw Error.noWallet
    }
    
    let wallet: Wallet
    if let walletWithIdentifier = wallets.first(where: {
      guard let walletId = try? $0.identity.identifier().string else { return false }
      return walletId == walletIdentifier
    }) {
      wallet = walletWithIdentifier
    } else {
      wallet = wallets[0]
    }

    do {
      let balance = try await balanceService.loadWalletBalance(wallet: wallet, currency: currency)
      let rates = try await ratesService.loadRates(jettons: [], currencies: [currency])
      
      let formattedFiatBalance: String
      if let rate = rates.ton.first(where: { $0.currency == currency }) {
        let fiatAmount = RateConverter().convert(
          amount: balance.balance.tonBalance.amount,
          amountFractionLength: TonInfo.fractionDigits,
          rate: rate
        )
        formattedFiatBalance = amountFormatter.formatAmountWithoutFractionIfThousand(
          fiatAmount.amount,
          fractionDigits: fiatAmount.fractionLength,
          maximumFractionDigits: 2,
          currency: currency
        )
      } else {
        formattedFiatBalance = "\(currency.symbol)-----"
      }
      let formattedBalance = amountFormatter.formatAmount(
        BigUInt(integerLiteral: UInt64(balance.balance.tonBalance.amount)),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2
      )
      return Model(
        tonBalance: formattedBalance,
        fiatBalance: formattedFiatBalance,
        address: try wallet.address.toShortString(bounceable: false)
        )
    } catch {
      throw Error.failedToLoad
    }
  }
}
