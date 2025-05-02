import Foundation
import TonSwift
import CoreComponents

protocol RatesRepository {
  func saveRates(_ rates: Rates) throws
  func getRates() throws -> Rates
}

struct RatesRepositoryImplementation: RatesRepository {
  let fileSystemVault: FileSystemVault<[Rates.Rate], String>
  
  init(fileSystemVault: FileSystemVault<[Rates.Rate], String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func saveRates(_ rates: Rates) throws {
    try fileSystemVault.saveItem(rates.ton, key: TonInfo.symbol.lowercased())
    try fileSystemVault.saveItem(rates.usdt, key: "usdt")
  }
  
  func getRates() throws -> Rates {
    let tonRates = try fileSystemVault.loadItem(key: TonInfo.symbol.lowercased())
    let usdtRates = try fileSystemVault.loadItem(key: "usdt")
    
    return Rates(
      ton: tonRates,
      usdt: usdtRates,
      jettonRates: [:]
    )
  }
}
