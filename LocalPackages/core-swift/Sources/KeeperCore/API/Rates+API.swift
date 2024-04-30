import Foundation
import TonAPI

extension Rates.Rate {
  init?(tokenRates: Components.Schemas.TokenRates?) {
     let rates = tokenRates?.prices?.additionalProperties.compactMap { currencyCode, value -> Rates.Rate? in
      guard let currency = Currency(code: currencyCode) else { return nil }
      let rate = Decimal(value)
      let diff24h = tokenRates?.diff_24h?.additionalProperties.first(where: { $0.key == currencyCode })?.value
      return Rates.Rate(currency: currency, rate: rate, diff24h: diff24h)
    }
    print("Dsd")
    return nil
//    guard let prices = tokenRates.prices else { }
    
  }
//  init(accountAddress: Components.Schemas.AccountAddress) throws {
//    address = try Address.parse(accountAddress.address)
//    name = accountAddress.name
//    isScam = accountAddress.is_scam
//    isWallet = accountAddress.is_wallet
//  }
//  var tonRates = [Rates.Rate]()
//  var jettonsRates = [Rates.JettonRate]()
//  for key in rates.keys {
//    guard let jettonRates = rates[key] else { continue }
//    if key.lowercased() == TonInfo.symbol.lowercased() {
//      guard let prices = jettonRates.prices?.additionalProperties else { continue }
//      let diff24h = jettonRates.diff_24h?.additionalProperties
//      tonRates = prices.compactMap { price -> Rates.Rate? in
//        guard let currency = Currency(code: price.key) else { return nil }
//        let diff24h = diff24h?[price.key]
//        return Rates.Rate(currency: currency, rate: Decimal(price.value), diff24h: diff24h)
//      }
//      continue
//    }
//    guard let jettonInfo = jettons.first(where: { $0.address.toRaw() == key.lowercased()}) else { continue }
//    guard let prices = jettonRates.prices?.additionalProperties else { continue }
//    let diff24h = jettonRates.diff_24h?.additionalProperties
//    let rates: [Rates.Rate] = prices.compactMap { price -> Rates.Rate? in
//      guard let currency = Currency(code: price.key) else { return nil }
//      let diff24h = diff24h?[price.key]
//      return Rates.Rate(currency: currency, rate: Decimal(price.value), diff24h: diff24h)
//    }
//    jettonsRates.append(.init(jettonInfo: jettonInfo, rates: rates))
//    
//  }
//  return Rates(ton: tonRates, jettonsRates: jettonsRates)
}
