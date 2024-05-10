import Foundation
import TKUIKit
import TKCore
import KeeperCore

struct CurrencyListItemMapper {
  func mapCurrencyListItem(_ item: CurrencyListItemsModel.Item) -> SelectionCollectionViewCell.Configuration {
    let id = item.identifier
    let currencyCode = item.currency.code.withTextStyle(.label1, color: .Text.primary)
    let currencyTitle = item.currency.title.withTextStyle(.body1, color: .Text.secondary)
    
    let title = NSMutableAttributedString()
    title.append(currencyCode)
    title.appendSpacer(width: 8)
    title.append(currencyTitle)
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration:
          .init(
            title: title,
            tagViewModel: nil,
            subtitle: nil,
            description: nil
          ),
      rightItemConfiguration: nil
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: .init(iconConfiguration: .none, alignment: .center),
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .none
    )
    
    return SelectionCollectionViewCell.Configuration(
      id: id,
      listItemConfiguration: listItemConfiguration,
      accesoryConfiguration: .init(accessoryType: .checkmark),
      accesoryAlignment: .right
    )
  }
}

private extension CGFloat {
  static let spaceSymbolWidth: CGFloat = NSAttributedString(string: " ").size().width
}

private extension NSMutableAttributedString {
  func appendSpacer(width spacingWidth: CGFloat) {
    let spacer = NSAttributedString(string: " ", attributes: [.kern: spacingWidth - CGFloat.spaceSymbolWidth])
    self.append(spacer)
  }
}
