import Foundation
import TKUIKit
import TKCore
import KeeperCore

final class SwapTokenListItemMapper {
  
  let imageLoader = ImageLoader()
  
  func mapTokenListItem(_ item: TokenListItemsModel.Item, selectionClosure: @escaping (() -> Void)) -> TKUIListItemCell.Configuration {
    let id = item.symbol
    let title = item.symbol.withTextStyle(.label1, color: .Text.primary)
    let subtitle = item.displayName.withTextStyle(.body2, color: .Text.secondary)
    
    let zeroValue = "0".withTextStyle(.label1, color: .Text.tertiary)
    let value = item.balance?.withTextStyle(.label1, color: .Text.primary) ?? zeroValue
    let valueSubtitle = item.balanceConverted?.withTextStyle(.body2, color: .Text.secondary)
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: .init(
        title: title,
        tagViewModel: mapBadgeText(item.badge),
        subtitle: subtitle,
        description: nil
      ),
      rightItemConfiguration: .init(
        value: value,
        subtitle: valueSubtitle,
        description: nil
      )
    )
    
    let iconViewConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration: .image(
        .init(
          image:  mapItemImage(item.image),
          tintColor: .clear,
          backgroundColor: .Background.contentTint,
          size: CGSize(width: 44, height: 44),
          cornerRadius: 22
        )
      ),
      alignment: .center
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconViewConfiguration,
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .none
    )
    
    return TKUIListItemCell.Configuration(
      id: id,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: selectionClosure
    )
  }
  
  private func mapItemImage(_ itemImage: TokenListItemsModel.Item.Image) -> TKUIListItemImageIconView.Configuration.Image {
    switch itemImage {
    case .image(let image):
      return .image(image)
    case .asyncImage(let url):
      let iconImageDownloadTask = TKCore.ImageDownloadTask { [imageLoader] imageView, size, cornerRadius in
        return imageLoader.loadImage(
          url: url,
          imageView: imageView,
          size: size,
          cornerRadius: cornerRadius
        )
      }
      return .asyncImage(url, iconImageDownloadTask)
    }
  }
  
  private func mapBadgeText(_ tagText: String?) -> TKUITagView.Configuration? {
    guard let tagText else { return nil }
    return TKUITagView.Configuration(
      text: tagText,
      textColor: .Text.secondary,
      backgroundColor: .Background.contentTint
    )
  }
}
