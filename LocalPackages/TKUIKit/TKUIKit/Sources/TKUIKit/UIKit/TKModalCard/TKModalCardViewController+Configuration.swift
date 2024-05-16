import UIKit

public extension TKModalCardViewController {
  struct Configuration {
    public var header: Header?
    public var content: Content?
    public var actionBar: ActionBar?
    
    public init(header: Header? = nil,
                content: Content? = nil,
                actionBar: ActionBar? = nil) {
      self.header = header
      self.content = content
      self.actionBar = actionBar
    }
  }
}

public extension TKModalCardViewController.Configuration {
  enum Item {
    case text(Text, bottomSpacing: CGFloat)
    case button(Button, bottomSpacing: CGFloat)
    case buttonsRow(ButtonsRow, bottomSpacing: CGFloat, itemSpacing: CGFloat)
    case customView(UIView, bottomSpacing: CGFloat)
    case customViewController(UIViewController, bottomSpacing: CGFloat)
  }
  
  struct Text {
    public let text: NSAttributedString?
    public let numberOfLines: Int
    
    public init(text: NSAttributedString?, numberOfLines: Int) {
      self.text = text
      self.numberOfLines = numberOfLines
    }
  }
  
  struct ListItem {
    public enum RightItem<T> {
      case loading
      case value(T, numberOfLines: Int, isFullString: Bool)
      
      public var value: T? {
        guard case let .value(value, _, _) = self else { return nil }
        return value
      }
    }
    
    public let left: String
    public let rightTop: RightItem<String>
    public let rightBottom: RightItem<String?>
    public let copyableValue: String?

    public init(
      left: String,
      rightTop: RightItem<String>,
      rightBottom: RightItem<String?>, 
      copyableValue: String? = nil
    ) {
      self.left = left
      self.rightTop = rightTop
      self.rightBottom = rightBottom
      self.copyableValue = copyableValue
    }
  }
  
  struct Button {
    public let title: String?
    public let size: TKUIActionButtonSize
    public let category: TKUIActionButtonCategory
    public let isEnabled: Bool
    public let isActivity: Bool
    public let tapAction: (( @escaping (_ isActivity: Bool) -> Void, @escaping (_ isSuccess: Bool) -> Void ) -> Void)?
    public let completionAction: ((Bool) -> Void)?
    
    public init(title: String?,
                size: TKUIActionButtonSize,
                category: TKUIActionButtonCategory,
                isEnabled: Bool,
                isActivity: Bool,
                tapAction: ((@escaping (_ isActivity: Bool) -> Void, @escaping (_ isSuccess: Bool) -> Void) -> Void)? = nil,
                completionAction: ( (Bool) -> Void)? = nil) {
      self.title = title
      self.size = size
      self.category = category
      self.isEnabled = isEnabled
      self.isActivity = isActivity
      self.tapAction = tapAction
      self.completionAction = completionAction
    }
  }
  
  struct ButtonsRow {
    public let buttons: [Button]
    
    public init(buttons: [Button]) {
      self.buttons = buttons
    }
  }
}

public extension TKModalCardViewController.Configuration {
  enum ContentItem {
    case item(Item)
    case list([ListItem])
  }
}

public extension TKModalCardViewController.Configuration {
  struct Header {
    public let items: [Item]
    
    public init(items: [Item]) {
      self.items = items
    }
  }
  
  struct ActionBar {
    public let items: [Item]
    
    public init(items: [Item]) {
      self.items = items
    }
  }
  
  struct Content {
    public let items: [ContentItem]
    
    public init(items: [ContentItem]) {
      self.items = items
    }
  }
}

