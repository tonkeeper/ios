import Foundation
import TonSwift
import CoreComponents

protocol RatesRepository {
  func saveRates(_ rates: Rates) throws
  func getRates(jettons: [JettonInfo]) throws -> Rates
}

struct RatesRepositoryImplementation: RatesRepository {
  let fileSystemVault: FileSystemVault<[Rates.Rate], String>
  
  init(fileSystemVault: FileSystemVault<[Rates.Rate], String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func saveRates(_ rates: Rates) throws {
    try fileSystemVault.saveItem(rates.ton, key: TonInfo.symbol.lowercased())
    
    for jettonRates in rates.jettonsRates {
      try fileSystemVault.saveItem(
        jettonRates.rates,
        key: jettonRates.jettonInfo.address.toRaw()
      )
    }
  }
  
  func getRates(jettons: [JettonInfo]) throws -> Rates {
    let tonRates = try fileSystemVault.loadItem(key: TonInfo.symbol.lowercased())
    let jettonsRates = jettons.compactMap { jettonInfo -> Rates.JettonRate? in
      guard let rates = try? fileSystemVault.loadItem(key: jettonInfo.address.toRaw()) else {
        return nil
      }
      return Rates.JettonRate(
        jettonInfo: jettonInfo,
        rates: rates
      )
    }
    return Rates(
      ton: tonRates,
      jettonsRates: jettonsRates
    )
  }
}
