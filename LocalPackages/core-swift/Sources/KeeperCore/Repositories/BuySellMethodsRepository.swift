import Foundation
import CoreComponents

protocol BuySellMethodsRepository {
  func saveFiatMethods(_ fiatMethods: FiatMethods) throws
  func getFiatMethods() throws -> FiatMethods
}

final class BuySellMethodsRepositoryImplementation: BuySellMethodsRepository {
  let fileSystemVault: FileSystemVault<FiatMethods, String>
  
  init(fileSystemVault: FileSystemVault<FiatMethods, String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func saveFiatMethods(_ fiatMethods: FiatMethods) throws {
    try fileSystemVault.saveItem(fiatMethods, key: .key)
  }
  
  func getFiatMethods() throws -> FiatMethods {
    return try fileSystemVault.loadItem(key: .key)
  }
}

private extension String {
  static let key = "FiatMethods"
}
