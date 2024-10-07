import UIKit

public enum TKStories {
  public static func storiesViewController(models: [StoriesPageModel]) -> StoriesViewController {
    StoriesViewController(models: models)
  }
}
