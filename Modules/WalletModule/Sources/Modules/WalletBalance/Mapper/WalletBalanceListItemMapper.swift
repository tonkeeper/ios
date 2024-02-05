import UIKit
import TKUIKit
import TKCore
import KeeperCore

struct WalletBalanceListItemMapper {
  
  let imageLoader = ImageLoader()
  
  func mapBalanceItems(_ item: WalletBalanceModel.Item,
                       selectionHandler: @escaping () -> Void) -> WalletBalanceBalanceItemCell.Model {
    
    let subtitle = NSMutableAttributedString()
    
    switch item.verification {
    case .none:
      subtitle.append("Unverified Token".withTextStyle(.body2, color: .Accent.orange, alignment: .left, lineBreakMode: .byTruncatingTail))
    case .whitelist:
      if let price = item.price?.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      ) {
        subtitle.append(price)
        subtitle.append(" ".withTextStyle(.body2, color: .Text.secondary))
      }
      
      if let diff = item.rateDiff {
        let color: UIColor
        if diff.hasPrefix("-") {
          color = .Accent.red
        } else {
          color = .Accent.green
        }
        subtitle.append(diff.withTextStyle(.body2, color: color, alignment: .left))
      }
    case .blacklist:
      subtitle.append("Unverified Token".withTextStyle(.body2, color: .Accent.orange, alignment: .left, lineBreakMode: .byTruncatingTail))
    }
    
    let contentViewModel = TKListItemContentStackView.Model(
      titleSubtitleModel: TKListItemTitleSubtitleView.Model(
        title: item.title.withTextStyle(.label1, color: .white, alignment: .left, lineBreakMode: .byTruncatingTail),
        subtitle: subtitle
      ),
      description: nil
    )

    let rightContentViewModel = TKListItemContentStackView.Model(
      titleSubtitleModel: TKListItemTitleSubtitleView.Model(
        title: item.amount?.withTextStyle(.label1, color: .white, alignment: .right, lineBreakMode: .byTruncatingTail),
        subtitle: item.convertedAmount?.withTextStyle(.body2, color: .Text.secondary, alignment: .right, lineBreakMode: .byTruncatingTail)
      ),
      description: nil
    )
    
    let contentModel = TKListItemContentView.Model(
      leftContentStackViewModel: contentViewModel,
      rightContentStackViewModel: rightContentViewModel
    )
    
    let image: TKListItemIconImageView.Model.Image
    switch item.image {
    case .ton:
      image = .image(.TKCore.Icons.Size44.tonLogo)
    case .url(let url):
      image = .asyncImage(url)
    }
    
    let iconModel = TKListItemIconImageView.Model(
      image: image,
      tintColor: .clear,
      backgroundColor: .clear,
      size: CGSize(width: 44, height: 44)
    )

    let cellModel = WalletBalanceBalanceItemCell.Model(
      identifier: item.identifier,
      isSelectable: false,
      selectionHandler: selectionHandler,
      cellContentModel: WalletBalanceBalanceItemCellContentView.Model(
        iconModel: iconModel,
        contentModel: contentModel
      )
    )
    return cellModel
  }
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
}

private extension CGFloat {
  static let iconCornerRadius: CGFloat = 22
}
