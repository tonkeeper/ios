import Foundation
import TonAPI

protocol BuySellMethodsService {
  func loadFiatMethods(countryCode: String?) async throws -> FiatMethods
  func getFiatMethods() throws -> FiatMethods
  func saveFiatMethods(_ fiatMethods: FiatMethods) throws
}

final class BuySellMethodsServiceImplementation: BuySellMethodsService {
  private let api: TonkeeperAPI
  private let buySellMethodsRepository: BuySellMethodsRepository
  
  init(api: TonkeeperAPI,
       buySellMethodsRepository: BuySellMethodsRepository) {
    self.api = api
    self.buySellMethodsRepository = buySellMethodsRepository
  }
  
  func loadFiatMethods(countryCode: String?) async throws -> FiatMethods {
    let methods = try await api.loadFiatMethods(countryCode: countryCode)
    return methods
  }
  
  func getFiatMethods() throws -> FiatMethods {
    try buySellMethodsRepository.getFiatMethods()
  }
  
  func saveFiatMethods(_ fiatMethods: FiatMethods) throws {
    try buySellMethodsRepository.saveFiatMethods(fiatMethods)
  }
}
