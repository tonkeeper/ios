import UIKit

public enum Stories {
  public static func storiesViewController(models: [StoriesPageModel]) -> StoriesViewController {
    StoriesViewController(models: models)
  }
}
