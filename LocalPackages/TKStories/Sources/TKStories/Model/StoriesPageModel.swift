import UIKit

public struct StoriesPageModel {
  public struct Button {
    public let title: String
    public let action: () -> Void
    
    public init(title: String,
                action: @escaping () -> Void) {
      self.title = title
      self.action = action
    }
  }
  
  public let title: String
  public let description: String
  public let button: Button?
  public let backgroundImage: UIImage
  
  public init(title: String,
              description: String,
              button: Button? = nil,
              backgroundImage: UIImage) {
    self.title = title
    self.description = description
    self.button = button
    self.backgroundImage = backgroundImage
  }
}
