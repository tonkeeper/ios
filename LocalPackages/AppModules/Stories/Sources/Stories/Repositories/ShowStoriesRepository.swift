import Foundation
import CoreComponents

protocol ShownStoriesRepository {
  func saveShownStories(_ storyIds: [String]) throws
  func getShownStories() throws -> [String]
}

final class ShownStoriesRepositoryImplementation: ShownStoriesRepository {
  let fileSystemVault: FileSystemVault<Set<String>, String>

  init(fileSystemVault: FileSystemVault<Set<String>, String>) {
    self.fileSystemVault = fileSystemVault
  }

  func saveShownStories(_ storyIds: [String]) throws {
    let shownStories = Set((try? getShownStories()) ?? [])
    let updatedShownStories = shownStories.union(storyIds)
    try fileSystemVault.saveItem(updatedShownStories, key: .key)
  }

  func getShownStories() throws -> [String] {
    do {
      return Array(try fileSystemVault.loadItem(key: .key))
    } catch {
      return []
    }
  }
}

private extension String {
  static let key = "ShownStories"
}
