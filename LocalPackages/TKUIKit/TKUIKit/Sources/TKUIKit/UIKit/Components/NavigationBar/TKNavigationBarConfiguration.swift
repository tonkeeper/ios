import UIKit

public extension TKNavigationBar {
  struct Configuration {
    public var rightButtonItems: [HeaderButtonItem]
    
    public init(rightButtonItems: [HeaderButtonItem]) {
      self.rightButtonItems = rightButtonItems
    }
  }
  
  struct HeaderButtonItem {
    public let model: TKUIHeaderIconButton.Model
    public let action: () -> Void
    
    public init(model: TKUIHeaderIconButton.Model, action: @escaping () -> Void) {
      self.model = model
      self.action = action
    }
  }
}
