import UIKit
import TKUIKit

class WalletsListWalletCell: TKCollectionViewContainerCell<WalletsListWalletCellContentView> {
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .Background.content
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

final class WalletsListWalletCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
  var padding: UIEdgeInsets { .init(top: 16, left: 16, bottom: 16, right: 16) }
  
  let iconView = TKListItemIconEmojiView()
  let contentView = TKListItemContentView()
  
  lazy var layout = TKListItemLayout(iconView: iconView, contentView: contentView, valueView: nil)
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    layout.layouSubviews(bounds: bounds)
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return layout.calculateSize(targetSize: size)
  }
  
  struct Model {
    let iconModel: TKListItemIconEmojiView.Model
    let contentModel: TKListItemContentView.Model
    
    init(emoji: String,
         backgroundColor: UIColor,
         walletName: String,
         walletTag: String?,
         balance: String) {
      iconModel = TKListItemIconEmojiView.Model(
        emoji: emoji,
        backgroundColor: backgroundColor
      )
      
      var tagModel: TKTagView.Model?
      if let walletTag {
        tagModel = TKTagView.Model(
          title: walletTag.withTextStyle(
            .body4,
            color: .Text.secondary,
            alignment: .center,
            lineBreakMode: .byWordWrapping
          )
        )
      }
      
      let leftContentStackViewModel = TKListItemContentStackView.Model(
        titleSubtitleModel: TKListItemTitleSubtitleView.Model(
          title: walletName.withTextStyle(
            .label1,
            color: .Text.primary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
          ),
          tagModel: tagModel,
          subtitle: balance.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
          )
        ),
        description: nil
      )
      
      contentModel = TKListItemContentView.Model(
        leftContentStackViewModel: leftContentStackViewModel,
        rightContentStackViewModel: nil
      )
    }
  }
  
  func configure(model: Model) {
    iconView.configure(model: model.iconModel)
    contentView.configure(model: model.contentModel)
  }
}

private extension WalletsListWalletCellContentView {
  func setup() {
    addSubview(iconView)
    addSubview(contentView)
  }
}
