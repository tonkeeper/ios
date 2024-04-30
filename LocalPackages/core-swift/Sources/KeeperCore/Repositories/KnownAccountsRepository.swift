import Foundation
import CoreComponents

protocol KnownAccountsRepository {
  func saveKnownAccounts(_ knownAccounts: [KnownAccount]) throws
  func getKnownAccounts() -> [KnownAccount]
}

final class KnownAccountsRepositoryImplementation: KnownAccountsRepository {
  let fileSystemVault: FileSystemVault<[KnownAccount], String>
  
  init(fileSystemVault: FileSystemVault<[KnownAccount], String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func saveKnownAccounts(_ knownAccounts: [KnownAccount]) throws {
    try fileSystemVault.saveItem(knownAccounts, key: .key)
  }
  
  func getKnownAccounts() -> [KnownAccount] {
    if let cached = try? fileSystemVault.loadItem(key: .key) {
      return cached
    } else if let bundled = try? getBundledKnownAccounts() {
      return bundled
    } else {
      return []
    }
  }
}

private extension KnownAccountsRepositoryImplementation {
  func getBundledKnownAccounts() throws -> [KnownAccount] {
    guard let url = Bundle.module.url(
      forResource: .knownAccountsFileName, withExtension: nil
    ) else {
      return []
    }
    let decoder = JSONDecoder()
    do {
        let data = try Data(contentsOf: url)
        let accounts = try decoder.decode(
            [KnownAccount].self,
            from: data
        )
        return accounts
    } catch {
        throw error
    }
  }
}

private extension String {
  static let key = "KnownAccounts"
}

private extension String {
  static let knownAccountsFileName = "known_accounts.json"
}
