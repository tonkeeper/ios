import Foundation
import CoreComponents

protocol StonfiPairsRepository {
  func savePairs(_ pairs: StonfiPairs) throws
  func getPairs() throws -> StonfiPairs
}

struct StonfiPairsRepositoryImplementation: StonfiPairsRepository {
  let fileSystemVault: FileSystemVault<StonfiPairs, String>
  
  init(fileSystemVault: FileSystemVault<StonfiPairs, String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func savePairs(_ pairs: StonfiPairs) throws {
    try fileSystemVault.saveItem(pairs, key: .stonfiPairsKey)
  }
  
  func getPairs() throws -> StonfiPairs {
    let pairs = try fileSystemVault.loadItem(key: .stonfiPairsKey)
    return pairs
  }
}

private extension String {
  static let stonfiPairsKey = "StonfiPairs"
}
