import UIKit
import TKUIKit
import TKCore
import KeeperCore

final class StakingEditAmountItemMapper {
  let imageLoader = ImageLoader()
  
  func mapStakingPoolItem(_ item: StakingEditAmountPoolItem) -> TKUIListItemView.Configuration {
    let title = item.name
    let tagText: String? = item.isMaxAPY ? .tagText : nil
    var subtitle = "\(String.apy) ≈ \(item.apyPercents)"
    if let apyProfit = item.profit {
      subtitle += " · \(apyProfit)"
    }
    
    let imageConfiguration: TKUIListItemImageIconView.Configuration.Image
    switch item.icon {
    case .fromResource:
      imageConfiguration = .image(item.implementation.image)
    case .url(let url):
      imageConfiguration = .asyncImage(
        url,
        TKCore.ImageDownloadTask(
          closure: {
            [imageLoader] imageView,
            size,
            cornerRadius in
            return imageLoader.loadImage(
              url: url,
              imageView: imageView,
              size: size,
              cornerRadius: cornerRadius
            )
          }
        )
      )
    }
    
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration: .image(
        .init(
          image: imageConfiguration,
          tintColor: .clear,
          backgroundColor: .clear,
          size: .iconSize,
          cornerRadius: CGSize.iconSize.height/2
        )
      ),
      alignment: .center
    )
    
    var tagConfiguration: TKUITagView.Configuration?
    if let tagText  {
      tagConfiguration = TKUITagView.Configuration(
        text: tagText,
        textColor: .Accent.green,
        backgroundColor: .Accent.green.withAlphaComponent(0.3)
      )
    }
    
    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: title.withTextStyle(.label1, color: .Text.primary),
      tagViewModel: tagConfiguration,
      subtitle: subtitle.withTextStyle(.body2, color: .Text.secondary),
      description: nil
    )
    
    return .init(
        iconConfiguration: iconConfiguration,
        contentConfiguration: .init(
          leftItemConfiguration: leftItemConfiguration,
          rightItemConfiguration: nil
        ),
        accessoryConfiguration: .image(
          .init(
            image: .TKUIKit.Icons.Size16.switch,
            tintColor: .Text.tertiary,
            padding: .zero
          )
        )
      )
  }
}

private extension CGSize {
  static let iconSize: Self = .init(width: 44, height: 44)
}

private extension String {
  static let apy = "APY"
  static let tagText = "MAX APY"
}

extension StakingPool.Implementation.Kind {
  var image: UIImage {
    switch self {
    case .whales:
      return .TKUIKit.Icons.Size44.tonWhalesLogo
    case .tf:
      return .TKUIKit.Icons.Size44.tonNominatorsLogo
    case .liquidTF:
      return .TKUIKit.Icons.Size44.tonStakersLogo
    }
  }
}
