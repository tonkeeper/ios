import UIKit

public struct StoriesPageModel {
  public let title: String
  public let description: String
  public let backgroundImage: UIImage
  
  public init(title: String,
              description: String,
              backgroundImage: UIImage) {
    self.title = title
    self.description = description
    self.backgroundImage = backgroundImage
  }
}
