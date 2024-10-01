import Foundation
import SwiftUI
import TKUIKit
import TonSwift

public final class StoriesController {
    public struct StoryButton {
      public let action: () -> Void
      public let title: String
      
      public init(title: String,
                  action: @escaping () -> Void
      ) {
        self.action = action
        self.title = title
      }
    }
  
  
  public struct StoryPage {
    public let title: String
    public let description: String
    public let button: Optional<StoryButton>
    public let backgroundImage: UIImage
    
    public init(title: String,
                description: String,
                button: Optional<StoryButton>,
                backgroundImage: UIImage) {
      self.title = title
      self.description = description
      self.button = button
      self.backgroundImage = backgroundImage
    }
  }
  
  public struct Model {
    public let pages: [StoryPage]
  }
  
  public var didUpdateModel: ((Model) -> Void)?

  private let pages: [StoryPage]
  
  init(pages: [StoryPage]) {
    self.pages = pages
  }
  
  public func createModel() {
    didUpdateModel?(
      Model(
        pages: self.pages
      )
    )
  }
}
