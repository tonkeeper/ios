import Foundation
import CoreComponents

protocol StonfiAssetsRepository {
  func saveAssets(_ assets: StonfiAssets) throws
  func getAssets() throws -> StonfiAssets
}

struct StonfiAssetsRepositoryImplementation: StonfiAssetsRepository {
  let fileSystemVault: FileSystemVault<StonfiAssets, String>
  
  init(fileSystemVault: FileSystemVault<StonfiAssets, String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func saveAssets(_ assets: StonfiAssets) throws {
    try fileSystemVault.saveItem(assets, key: .stonfiAssetsKey)
  }
  
  func getAssets() throws -> StonfiAssets {
    let assets = try fileSystemVault.loadItem(key: .stonfiAssetsKey)
    return assets
  }
}

private extension String {
  static let stonfiAssetsKey = "StonfiAssets"
}
