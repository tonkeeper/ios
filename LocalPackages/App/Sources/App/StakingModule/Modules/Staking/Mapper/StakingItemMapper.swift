import UIKit
import TKUIKit
import TKCore
import KeeperCore


struct StakingItemMapper {
  let imageLoader = ImageLoader()
  
  func mapOptionItem(_ item: OptionItem) -> StakingProviderView.Model {
    let imageConfiguration: TKUIListItemImageIconView.Configuration.Image
    switch item.image {
    case .ton:
      imageConfiguration = .image(.TKCore.Icons.Size44.tonLogo)
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
    
    let subtitle = "\(String.apy) ≈ \(item.apyPercents)"
    var tagText: String? = item.isMaxAPY ? .tagText : nil
    return .init(
      image: imageConfiguration,
      title: item.title,
      subtitle: subtitle,
      tagText: tagText
    )
  }
}

private extension String {
  static let apy = "APY"
  static let tagText = "MAX APY"
}
