import UIKit
import TKUIKit

extension TKUIListItemCell.Configuration {
  
  enum Accessory {
    case icon(UIImage, UIColor)
    case text(value: String)
  }
  
  enum Title {
    case string(String)
    case attributedString(NSAttributedString)
    
    var attributedString: NSAttributedString {
      switch self {
      case .attributedString(let attributedString):
        return attributedString
      case .string(let string):
        return string.withTextStyle(
          .label1,
          color: .Text.primary,
          alignment: .left
        )
      }
    }
  }
  
  static func createSettingsItem(
    id: String,
    title: Title,
    accessory: Accessory,
    selectionClosure: @escaping () -> Void) -> TKUIListItemCell.Configuration {
      let contentConfiguration = TKUIListItemContentView.Configuration(
        leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
          title: title.attributedString,
          tagViewModel: nil,
          subtitle: nil,
          description: nil
        ),
        rightItemConfiguration: nil
      )
      
      let accessoryConfiguration: TKUIListItemAccessoryView.Configuration
      switch accessory {
      case .icon(let icon, let tintColor):
        accessoryConfiguration = .image(
          TKUIListItemImageAccessoryView.Configuration(
            image: icon,
            tintColor: tintColor,
            padding: .zero
          )
        )
      case .text(let value):
        accessoryConfiguration = .text(
          TKUIListItemTextAccessoryView.Configuration(
            text: value.withTextStyle(
              .label1,
              color: .Accent.blue,
              alignment: .right,
              lineBreakMode: .byTruncatingTail
            )
          )
        )
      }
      
      let listItemConfiguration = TKUIListItemView.Configuration(
        iconConfiguration: TKUIListItemIconView.Configuration(
          iconConfiguration: .none,
          alignment: .center
        ),
        contentConfiguration: contentConfiguration,
        accessoryConfiguration: accessoryConfiguration
      )
      
      let configuration = TKUIListItemCell.Configuration(
        id: id,
        listItemConfiguration: listItemConfiguration,
        isHighlightable: true,
        selectionClosure: selectionClosure
      )
      return configuration
    }
}
