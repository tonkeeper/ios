import Foundation
import TKUIKit
import TKCore
import KeeperCore

struct BuySellOperatorItemMapper {
  let imageLoader = ImageLoader()
  
  func mapCurrencyPickerItem(_ item: CurrencyPickerItem, selectionClosure: @escaping () -> Void) -> TKUIListItemCell.Configuration {
    let id = item.id
    let currencyCode = item.currencyCode.withTextStyle(.label1, color: .Text.primary)
    let currencyTitle = item.currencyTitle.withTextStyle(.body1, color: .Text.secondary)
    
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
    
    let accessoryImageConfiguration = TKUIListItemImageAccessoryView.Configuration(
      image: .TKUIKit.Icons.Size16.switch,
      tintColor: .Icon.secondary,
      padding: .init(top: 0, left: 0, bottom: 0, right: 8)
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: .init(iconConfiguration: .none, alignment: .center),
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .image(accessoryImageConfiguration)
    )
    
    return TKUIListItemCell.Configuration(
      id: id,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: selectionClosure
    )
  }
  
  func mapFiatOperatorItem(_ item: FiatOperator, selectionClosure: @escaping () -> Void) -> SelectionCollectionViewCell.Configuration {
    let id = item.id
    let title = item.title.withTextStyle(.label1, color: .Text.primary)
    let subtitle = item.rate.withTextStyle(.body2, color: .Text.secondary)
    let tagViewModel = makeTagViewModel(item.badge)
    
    let iconImageDownloadTask = TKCore.ImageDownloadTask { [imageLoader] imageView, size, cornerRadius in
      return imageLoader.loadImage(
        url: item.iconURL,
        imageView: imageView,
        size: size,
        cornerRadius: cornerRadius
      )
    }
    
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration:
          .image(
            .init(
              image: .asyncImage(item.iconURL, iconImageDownloadTask),
              tintColor: .clear,
              backgroundColor: .Background.contentTint,
              size: .init(width: 44, height: 44),
              cornerRadius: 12
            )
          ),
      alignment: .center
    )
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration:
          .init(
            title: title,
            tagViewModel: tagViewModel,
            subtitle: subtitle,
            description: nil
          ),
      rightItemConfiguration: nil
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .none
    )
    
    return SelectionCollectionViewCell.Configuration(
      id: id,
      listItemConfiguration: listItemConfiguration,
      accesoryConfiguration: .init(accessoryType: .radioButton),
      accesoryAlignment: .right,
      selectionClosure: selectionClosure
    )
  }
  
  private func makeTagViewModel(_ tagText: String?) -> TKUITagView.Configuration? {
    guard let tagText else { return nil }
    return TKUITagView.Configuration(
      text: tagText,
      textColor: .Accent.blue,
      backgroundColor: .Accent.blue.withAlphaComponent(0.16)
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
