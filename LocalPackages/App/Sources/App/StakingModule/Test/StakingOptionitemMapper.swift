import UIKit
import TKUIKit
import TKCore
import KeeperCore

struct StakingOptionListItemMapper {
  let imageLoader = ImageLoader()
  
  func mapOptionItem(
    _ item: OptionItem,
    selectionClosure: @escaping ((String, Bool) -> Void),
    selClosure: @escaping (() -> Void)
  )  -> TKUIListItemCell.Configuration {
    let title = item.title.withTextStyle(
      .label1,
      color: .white,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let leftDescription = NSMutableAttributedString()
    leftDescription.append("\(String.apy) ≈ ".withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left
    ))
    let apyPercentsString = item.apyPercents.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left
    )
    leftDescription.append(apyPercentsString)
    
    let leftSubtitle = "\(String.minDeposit) \(item.minDepositAmount)"
      .withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left
      )
    
    if let apyTokenAmount = item.apyTokenAmount {
      leftDescription.append(" · \(apyTokenAmount)".withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left
      ))
    }
    
    var tagConfiguration: TKUITagView.Configuration? = nil
    if item.isMaxAPY {
      tagConfiguration = TKUITagView.Configuration(
        text: .tagText,
        textColor: .Accent.green,
        backgroundColor: .Accent.green.withAlphaComponent(0.3)
      )
    }
    
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
    
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration: .image(
        TKUIListItemImageIconView.Configuration(
          image: imageConfiguration,
          tintColor: .Icon.primary,
          backgroundColor: .Background.contentTint,
          size: .iconSize,
          cornerRadius: CGSize.iconSize.height/2
        )
      ),
      alignment: .center
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
          title: title,
          tagViewModel: tagConfiguration,
          subtitle: leftSubtitle,
          description: leftDescription
        ),
        rightItemConfiguration: nil
      ),
      accessoryConfiguration: createAccessoryConfiguration(item: item, selectionClosure: selectionClosure)
    )
    
    return .init(id: item.id, listItemConfiguration: listItemConfiguration, selectionClosure: selClosure)
  }
}

// MARK: - Private methods

private extension StakingOptionListItemMapper {
  func createAccessoryConfiguration(
    item: OptionItem,
    selectionClosure: @escaping ((String, Bool) -> Void)
  ) -> TKUIListItemAccessoryView.Configuration {
    if item.isPrefferable {
      return TKUIListItemAccessoryView.Configuration.radioButton(
        .init(
          isSelected: item.isSelected,
          size: 24,
          handler: { isSelected in
            selectionClosure(item.id, isSelected)
          })
      )
    }
    
    return TKUIListItemAccessoryView.Configuration.image(
      .init(
        image: .TKUIKit.Icons.Size16.chevronRight,
        tintColor: .Text.tertiary,
        padding: .zero
      )
    )
  }
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
}

private extension CGFloat {
  static let iconCornerRadius: CGFloat = 22
}

private extension String {
  static let apy = "APY"
  static let minDeposit = "Minimum deposit"
  static let tagText = "MAX APY"
}
