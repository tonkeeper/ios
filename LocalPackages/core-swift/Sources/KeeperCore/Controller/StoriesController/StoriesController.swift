import Foundation
import SwiftUI
import TKUIKit
import TonSwift

public final class StoriesController {
  public struct StoryPage {
    public let title: String
    public let description: String
    public let buttonTitle: Optional<String>
    public let backgroundImage: UIImage
    
    public init(title: String,
                description: String,
                buttonTitle: Optional<String>,
                backgroundImage: UIImage) {
      self.title = title
      self.description = description
      self.buttonTitle = buttonTitle
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
