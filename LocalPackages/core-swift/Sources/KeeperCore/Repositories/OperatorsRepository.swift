import Foundation
import CoreComponents

protocol OperatorsRepository {
  func saveOperators(_ operators: [Operator], type: FiatMethodCategoryType, currency: Currency) throws
  func getOperators(type: FiatMethodCategoryType, currency: Currency) throws -> [Operator]
}

final class OperatorsRepositoryImplementation: OperatorsRepository {
  let fileSystemVault: FileSystemVault<[Operator], String>
  
  init(fileSystemVault: FileSystemVault<[Operator], String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func saveOperators(_ operators: [Operator], type: FiatMethodCategoryType, currency: Currency) throws {
    let key = key(type: type, currency: currency)
    try fileSystemVault.saveItem(operators, key: key)
  }
  
  func getOperators(type: FiatMethodCategoryType, currency: Currency) throws -> [Operator] {
    let key = key(type: type, currency: currency)
    return try fileSystemVault.loadItem(key: key)
  }
  
  private func key(type: FiatMethodCategoryType, currency: Currency) -> String {
    return "\(type.rawValue)\(currency.rawValue)"
  }
}
