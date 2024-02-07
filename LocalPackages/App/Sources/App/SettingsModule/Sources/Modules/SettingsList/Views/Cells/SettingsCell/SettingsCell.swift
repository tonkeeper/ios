import UIKit
import TKUIKit

final class SettingsCell: TKCollectionViewContainerCell<SettingsCellContentView> {
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .Background.content
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

final class SettingsCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
  var padding: UIEdgeInsets { .init(top: 16, left: 16, bottom: 16, right: 16) }
  
  let contentView = TKListItemContentView()
  let valueView = SettingsCellValueView()
  
  lazy var layout = TKListItemLayout(iconView: nil, contentView: contentView, valueView: valueView)
  
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
    let contentModel: TKListItemContentView.Model
    let valueModel: SettingsCellValueView.Model?
    
    init(title: String,
         subtitle: String? = nil,
         icon: UIImage?,
         tintColor: UIColor) {
      self.contentModel = TKListItemContentView.Model(
        leftContentStackViewModel: TKListItemContentStackView.Model(
          titleSubtitleModel: TKListItemTitleSubtitleView.Model(
            title: title.withTextStyle(
              .label1,
              color: .Text.primary,
              alignment: .left,
              lineBreakMode: .byTruncatingTail
            ),
            subtitle: subtitle?.withTextStyle(
              .body2,
              color: .Text.secondary,
              alignment: .left,
              lineBreakMode: .byTruncatingTail
            )
          ),
          description: nil
        ),
        rightContentStackViewModel: nil
      )
      
      valueModel = .icon(
        SettingsCellIconValueView.Model(
          image: icon,
          tintColor: tintColor,
          backgroundColor: .clear,
          size: CGSize(width: 28, height: 28)
        )
      )
    }
    
    init(title: String,
         subtitle: String? = nil,
         value: String) {
      self.contentModel = TKListItemContentView.Model(
        leftContentStackViewModel: TKListItemContentStackView.Model(
          titleSubtitleModel: TKListItemTitleSubtitleView.Model(
            title: title.withTextStyle(
              .label1,
              color: .Text.primary,
              alignment: .left,
              lineBreakMode: .byTruncatingTail
            ),
            subtitle: subtitle?.withTextStyle(
              .body2,
              color: .Text.secondary,
              alignment: .left,
              lineBreakMode: .byTruncatingTail
            )
          ),
          description: nil
        ),
        rightContentStackViewModel: nil
      )
      
      valueModel = .text(SettingsCellTextValueView.Model(text: value))
    }
    
    init(title: String,
         subtitle: String? = nil) {
      self.contentModel = TKListItemContentView.Model(
        leftContentStackViewModel: TKListItemContentStackView.Model(
          titleSubtitleModel: TKListItemTitleSubtitleView.Model(
            title: title.withTextStyle(
              .label1,
              color: .Text.primary,
              alignment: .left,
              lineBreakMode: .byTruncatingTail
            ),
            subtitle: subtitle?.withTextStyle(
              .body2,
              color: .Text.secondary,
              alignment: .left,
              lineBreakMode: .byTruncatingTail
            )
          ),
          description: nil
        ),
        rightContentStackViewModel: nil
      )
      
      valueModel = nil
    }
    
    init(title: NSAttributedString) {
      self.contentModel = TKListItemContentView.Model(
        leftContentStackViewModel: TKListItemContentStackView.Model(
          titleSubtitleModel: TKListItemTitleSubtitleView.Model(
            title: title,
            subtitle: nil
          ),
          description: nil
        ),
        rightContentStackViewModel: nil
      )
      
      valueModel = nil
    }
  }
  
  func configure(model: Model) {
    contentView.configure(model: model.contentModel)
    if let valueModel = model.valueModel {
      valueView.configure(model: valueModel)
      valueView.isHidden = false
    } else {
      valueView.isHidden = true
    }
  }
  
  func prepareForReuse() {
    contentView.prepareForReuse()
  }
}

private extension SettingsCellContentView {
  func setup() {
    addSubview(valueView)
    addSubview(contentView)
  }
}

