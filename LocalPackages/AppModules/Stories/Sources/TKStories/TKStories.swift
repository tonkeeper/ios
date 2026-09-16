import UIKit

public enum TKStoriesFactory {
    public static func storiesViewController(models: [StoriesPageModel]) -> StoriesViewController {
        StoriesViewController(models: models)
    }
}
