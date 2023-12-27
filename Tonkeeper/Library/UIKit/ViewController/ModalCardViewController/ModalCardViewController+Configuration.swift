//
//  ModalCardViewController+Configuration.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 20.10.2023.
//

import UIKit

extension ModalCardViewController {
  struct Configuration {
    var header: Header?
    var content: Content?
    var actionBar: ActionBar?
  }
}

extension ModalCardViewController.Configuration {
  enum Item {
    case text(Text, bottomSpacing: CGFloat)
    case button(Button, bottomSpacing: CGFloat)
    case buttonsRow(ButtonsRow, bottomSpacing: CGFloat, itemSpacing: CGFloat)
    case customView(UIView, bottomSpacing: CGFloat)
    case customViewController(UIViewController, bottomSpacing: CGFloat)
  }
  
  struct Text {
    let text: NSAttributedString?
    let numberOfLines: Int
  }
  
  struct ListItem {
    enum RightItem<T> {
      case loading
      case value(T, numberOfLines: Int, isFullString: Bool)
      
      var value: T? {
        guard case let .value(value, _, _) = self else { return nil }
        return value
      }
    }
    
    let left: String
    let rightTop: RightItem<String>
    let rightBottom: RightItem<String?>
  }
  
  struct Button {
    let title: String?
    let configuration: TKButton.Configuration
    let isEnabled: Bool
    let isActivity: Bool
    let tapAction: (( @escaping (_ isActivity: Bool) -> Void, @escaping (_ isSuccess: Bool) -> Void ) -> Void)?
    let completionAction: ((Bool) -> Void)?
    
    init(title: String?,
         configuration: TKButton.Configuration,
         isEnabled: Bool,
         isActivity: Bool,
         tapAction: ((@escaping (_ isActivity: Bool) -> Void, @escaping (_ isSuccess: Bool) -> Void) -> Void)? = nil,
         completionAction: ( (Bool) -> Void)? = nil) {
      self.title = title
      self.configuration = configuration
      self.isEnabled = isEnabled
      self.isActivity = isActivity
      self.tapAction = tapAction
      self.completionAction = completionAction
    }
  }
  
  struct ButtonsRow {
    let buttons: [Button]
  }
}

extension ModalCardViewController.Configuration {
  enum ContentItem {
    case item(Item)
    case list([ListItem])
  }
}

extension ModalCardViewController.Configuration {
  struct Header {
    let items: [Item]
  }
  
  struct ActionBar {
    let items: [Item]
  }
  
  struct Content {
    let items: [ContentItem]
  }
}

