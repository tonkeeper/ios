import Foundation
import CoreComponents

public protocol CurrencyService {
  func setActiveCurrency(_ currency: Currency) throws
  func getActiveCurrency() throws -> Currency
}

final class CurrencyServiceImplementation: CurrencyService {
  let keeperInfoRepository: KeeperInfoRepository
  
  init(keeperInfoRepository: KeeperInfoRepository) {
    self.keeperInfoRepository = keeperInfoRepository
  }
  
  func setActiveCurrency(_ currency: Currency) throws {
    let keeperInfo = try keeperInfoRepository.getKeeperInfo()
    let updatedKeeperInfo = keeperInfo.setCurrency(currency)
    try keeperInfoRepository.saveKeeperInfo(updatedKeeperInfo)
  }
  
  func getActiveCurrency() throws -> Currency {
    let keeperInfo = try keeperInfoRepository.getKeeperInfo()
    return keeperInfo.currency
  }
}
