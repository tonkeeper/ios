import Foundation
import BigInt
import TonSwift

public final class SwapController {

  private let ratesService: RatesService
  
  init(ratesService: RatesService) {
    self.ratesService = ratesService
  }
  
  public func calculateReceiveRate(
    sendToken: Token,
    amount: BigUInt,
    receiveToken: Token
  ) async throws -> BigUInt {
    print(amount)
    if amount == 0 { return 0 }
    let jettons: [JettonInfo] = [sendToken, receiveToken].compactMap {
      if case .jetton(let jettonItem) = $0 { return jettonItem.jettonInfo } else { return nil }
    }
    let rates = try await ratesService.loadRates(jettons: jettons, currencies: [.TON])
    let tonSendRate = getTonRate(for: sendToken, tonRates: rates.ton, jettonRates: rates.jettonsRates)
    let tonReceiveRate = getTonRate(for: receiveToken, tonRates: rates.ton, jettonRates: rates.jettonsRates)
    let converter = RateConverter()
    let converted = converter.convert(amount: amount, amountFractionLength: sendToken.tokenFractionalDigits, rate: tonSendRate / tonReceiveRate)

    print(converted)
    let convertedPlainString = String(converted.amount)
    let symbols = (convertedPlainString.count - converted.fractionLength) + receiveToken.tokenFractionalDigits
    let final = convertedPlainString[..<convertedPlainString.index(convertedPlainString.startIndex, offsetBy: symbols)]
    return BigUInt(stringLiteral: String(final))
  }

  private func getTonRate(
    for token: Token,
    tonRates: [Rates.Rate],
    jettonRates: [Rates.JettonRate]
  ) -> Decimal {
    switch token {
    case .ton:
      return tonRates.first { $0.currency == .TON }?.rate ?? 0
    case .jetton(let item):
      return jettonRates.first { $0.jettonInfo == item.jettonInfo }?.rates.first { $0.currency == .TON }?.rate ?? 0
    }
  }
}
