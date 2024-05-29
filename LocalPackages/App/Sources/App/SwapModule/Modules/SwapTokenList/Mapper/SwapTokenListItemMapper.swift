import Foundation
import TKUIKit
import TKCore
import KeeperCore

struct SwapTokenListItemMapper {
  
  let imageLoader = CachedMemoryImageLoader(cacheExpirationInMinutes: 3)
  
  func mapTokenButtonListItem(_ item: TokenButtonListItemsModel.Item, selectionClosure: @escaping (() -> Void)) -> SuggestedTokenCell.Configuration {
    let id = item.identifier
    
    let tokenButtonModel = SwapTokenButtonContentView.Model(
      title: item.symbol.withTextStyle(.body2, color: .Button.tertiaryForeground),
      icon: createTokenButtonIcon(item.image)
    )
    
    return SuggestedTokenCell.Configuration(
      id: id,
      tokenButtonModel: tokenButtonModel,
      selectionClosure: selectionClosure
    )
  }
  
  func mapTokenListItem(_ item: SwapTokenListItemsModel.Item, selectionClosure: @escaping (() -> Void)) -> TKUIListItemCell.Configuration {
    let id = item.identifier
    let title = item.symbol.withTextStyle(.label1, color: .Text.primary)
    let subtitle = item.displayName.withTextStyle(.body2, color: .Text.secondary)
    
    let zeroValue = "0".withTextStyle(.label1, color: .Text.tertiary)
    let value = item.amount?.withTextStyle(.label1, color: .Text.primary) ?? zeroValue
    let valueSubtitle = item.convertedAmount?.withTextStyle(.body2, color: .Text.secondary)
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
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
        TKUIListItemImageIconView.Configuration(
          image: createTokenListIcon(item.image),
          tintColor: .clear,
          backgroundColor: .Background.contentTint,
          size: .iconSize,
          cornerRadius: .iconCornerRadius
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
}

private extension SwapTokenListItemMapper {
  func createTokenListIcon(_ imageModel: ImageModel) -> TKUIListItemImageIconView.Configuration.Image {
    switch imageModel {
    case .image(let image):
      return .image(image)
    case .asyncImage(let url):
      let iconImageDownloadTask = configureDownloadTask(forUrl: url)
      return .asyncImage(url, iconImageDownloadTask)
    }
  }
  
  func createTokenButtonIcon(_ imageModel: ImageModel) -> SwapTokenButtonContentView.Model.Icon {
    switch imageModel {
    case .image(let image):
      return .image(image)
    case .asyncImage(let url):
      let iconImageDownloadTask = configureDownloadTask(forUrl: url)
      return .asyncImage(iconImageDownloadTask)
    }
  }
  
  func configureDownloadTask(forUrl url: URL?) -> TKCore.ImageDownloadTask {
    TKCore.ImageDownloadTask { [imageLoader] imageView, size, cornerRadius in
      return imageLoader.loadImage(
        url: url,
        imageView: imageView,
        size: .iconSize,
        cornerRadius: .iconCornerRadius
      )
    }
  }
  
  func mapBadgeText(_ tagText: String?) -> TKUITagView.Configuration? {
    guard let tagText else { return nil }
    return TKUITagView.Configuration(
      text: tagText,
      textColor: .Text.secondary,
      backgroundColor: .Background.contentTint
    )
  }
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
}

private extension CGFloat {
  static let iconCornerRadius: CGFloat = 22
}
