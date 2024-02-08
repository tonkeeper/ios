import UIKit
import TKUIKit

final class HistoryEventActionView: UIControl, ConfigurableView {
  let highlightView = TKHighlightView()
  let contentView = UIView()
  let listItemView = HistoryEventActionListItemView()
  
  override var isHighlighted: Bool {
    didSet {
      highlightView.isHighlighted = isHighlighted
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    highlightView.frame = bounds
    contentView.frame = bounds.inset(by: .contentPadding)
    listItemView.frame = contentView.bounds
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let contentSize = size.inset(by: .contentPadding)
    let listItemViewSize = listItemView.sizeThatFits(contentSize)
    
    let resultSize = CGSize(width: contentSize.width, height: listItemViewSize.height)
      .padding(by: .contentPadding)
    return resultSize
  }
  
  struct Model {
    let listItemModel: HistoryEventActionListItemView.Model
  }
  
  func configure(model: Model) {
    listItemView.configure(model: model.listItemModel)
  }
  
  private func setup() {
    backgroundColor = .Background.content
    
    highlightView.isUserInteractionEnabled = false
    contentView.isUserInteractionEnabled = false
    
    highlightView.alpha = 1
    addSubview(highlightView)
    addSubview(contentView)
    contentView.addSubview(listItemView)
  }
}

final class HistoryEventActionListItemView: UIView, ConfigurableView, ReusableView {
  let iconView = HistoryEventIconView()
  let contentView = TKListItemContentView()
  
  lazy var layout = TKListItemLayout(
    iconView: iconView,
    contentView: contentView,
    valueView: nil
  )
  
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
  
  func prepareForReuse() {
    iconView.prepareForReuse()
    contentView.prepareForReuse()
  }
  
  struct Model {
    let iconModel: HistoryEventIconView.Model
    let contentViewModel: TKListItemContentView.Model
    
    init(image: UIImage?, 
         isInProgress: Bool,
         title: String?,
         subtitle: String?,
         value: NSAttributedString?,
         subvalue: NSAttributedString?,
         date: String?) {
      let title = title?.withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      
      let subtitle = subtitle?.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      
      let valueResult = NSMutableAttributedString()
      if let value = value {
        valueResult.append(value)
      }
      if let subvalue = subvalue {
        valueResult.append(NSAttributedString(string: "\n"))
        valueResult.append(subvalue)
      }

      let date = date?.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .right,
        lineBreakMode: .byTruncatingTail
      )
      
      contentViewModel = TKListItemContentView.Model(
        leftContentStackViewModel: TKListItemContentStackView.Model(
          titleSubtitleModel: TKListItemTitleSubtitleView.Model(
            title: title,
            subtitle: subtitle
          ),
          description: nil
        ),
        rightContentStackViewModel: TKListItemContentStackView.Model(
          titleSubtitleModel: TKListItemTitleSubtitleView.Model(
            title: valueResult,
            subtitle: date
          ),
          description: nil
        )
      )
      
      iconModel = HistoryEventIconView.Model(
        image: image,
        isInProgress: isInProgress
      )
    }
  }
  
  func configure(model: Model) {
    iconView.configure(model: model.iconModel)
    contentView.configure(model: model.contentViewModel)
    setNeedsLayout()
  }
  
  private func setup() {
    addSubview(iconView)
    addSubview(contentView)
  }
}


private extension UIEdgeInsets {
  static var contentPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
}
