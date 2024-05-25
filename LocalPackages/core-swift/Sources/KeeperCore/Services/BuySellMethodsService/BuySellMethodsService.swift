import Foundation
import TonAPI

protocol BuySellMethodsService {
  func loadFiatMethods(countryCode: String?) async throws -> FiatMethods
  func getFiatMethods() throws -> FiatMethods
  func saveFiatMethods(_ fiatMethods: FiatMethods) throws
  func loadOperators(type: FiatMethodCategoryType, currency: Currency) async throws -> [Operator]
  func getOperators(type: FiatMethodCategoryType, currency: Currency) throws -> [Operator]
  func saveOperators(_ operators: [Operator], type: FiatMethodCategoryType, currency: Currency) throws
}

final class BuySellMethodsServiceImplementation: BuySellMethodsService {
  private let api: TonkeeperAPI
  private let buySellMethodsRepository: BuySellMethodsRepository
  private let operatorsRepository: OperatorsRepository
  
  init(api: TonkeeperAPI,
       buySellMethodsRepository: BuySellMethodsRepository,
       operatorsRepository: OperatorsRepository
  ) {
    self.api = api
    self.buySellMethodsRepository = buySellMethodsRepository
    self.operatorsRepository = operatorsRepository
  }
  
  func loadOperators(type: FiatMethodCategoryType, currency: Currency) async throws -> [Operator] {
    let operators = try await api.loadOperators(type: type, currency: currency)
    return operators
  }
  
  func loadFiatMethods(countryCode: String?) async throws -> FiatMethods {
    let methods = try await api.loadFiatMethods(countryCode: countryCode)
    return methods
  }
  
  func getOperators(type: FiatMethodCategoryType, currency: Currency) throws -> [Operator] {
    try operatorsRepository.getOperators(type: type, currency: currency)
  }
  
  func saveOperators(_ operators: [Operator], type: FiatMethodCategoryType, currency: Currency) throws {
    try operatorsRepository.saveOperators(operators, type: type, currency: currency)
  }
  
  func getFiatMethods() throws -> FiatMethods {
    try buySellMethodsRepository.getFiatMethods()
  }
  
  func saveFiatMethods(_ fiatMethods: FiatMethods) throws {
    try buySellMethodsRepository.saveFiatMethods(fiatMethods)
  }
}
