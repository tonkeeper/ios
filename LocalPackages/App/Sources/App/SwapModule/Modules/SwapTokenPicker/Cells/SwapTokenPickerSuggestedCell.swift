import UIKit
import TKUIKit

class SwapTokenPickerSuggestedCell: TKCollectionViewContainerCell<SwapTokenPickerSuggestedCellContentView> {
  override init(frame: CGRect) {
    super.init(frame: frame)
    contentView.backgroundColor = .Background.content
    contentView.layer.cornerRadius = 18
    contentView.layer.masksToBounds = true
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

final class SwapTokenPickerSuggestedCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
  var padding: UIEdgeInsets { .init(top: 4, left: 4, bottom: 4, right: 4) }
  
  let iconView = TKListItemIconImageView()
  let contentView = TKTagView()
  
  lazy var layout = TKListTagItemLayout(iconView: iconView, contentView: contentView, valueView: nil)
  
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
    let iconModel: TKListItemIconImageView.Model
    let contentModel: TKTagView.Model
    
    init(image: TKListItemIconImageView.Model.Image,
         title: String) {
      iconModel = TKListItemIconImageView.Model(
        image: image,
        tintColor: .clear,
        backgroundColor: .clear,
        size: CGSize(width: 28, height: 28)
      )

      self.contentModel = TKTagView.Model(title: title.withTextStyle(.label1, color: .Text.primary, alignment: .center, lineBreakMode: .byTruncatingTail))
    }
  }
  
  func configure(model: Model) {
    iconView.configure(model: model.iconModel)
    contentView.configure(model: model.contentModel)
  }
}

private extension SwapTokenPickerSuggestedCellContentView {
  func setup() {
    addSubview(iconView)
    addSubview(contentView)
    contentView.backgroundColor = .clear
  }
}
