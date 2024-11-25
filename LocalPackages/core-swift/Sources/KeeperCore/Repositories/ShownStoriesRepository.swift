import Foundation
import CoreComponents

protocol ShownStoriesRepository {
  func saveShownStories(_ shownStories: [String]) throws
  func getShownStories() throws -> [String]
}

final class ShownStoriesRepositoryImplementation: ShownStoriesRepository {
  let fileSystemVault: FileSystemVault<[String], String>
  
  init(fileSystemVault: FileSystemVault<[String], String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func saveShownStories(_ shownStories: [String]) throws {
    try fileSystemVault.saveItem(shownStories, key: .key)
  }
  
  func getShownStories() throws -> [String] {
    do {
      return try fileSystemVault.loadItem(key: .key)
    } catch {
      return []
    }
  }
}

private extension String {
  static let key = "ShownStories"
}
