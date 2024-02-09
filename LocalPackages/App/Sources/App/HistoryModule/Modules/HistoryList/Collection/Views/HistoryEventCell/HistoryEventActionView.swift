import UIKit
import TKUIKit

final class HistoryEventActionView: UIControl, ConfigurableView, ReusableView {
  var isSeparatorVisible: Bool = true {
    didSet {
      updateSeparatorVisibility()
    }
  }
  
  let highlightView = TKHighlightView()
  let contentView = TKPassthroughView()
  let listItemView = HistoryEventActionListItemView()
  let statusView = StatusView()
  let descriptionView = CommentView()
  let commentView = CommentView()
  let nftView = NFTView()
  let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  
  override var isHighlighted: Bool {
    didSet {
      highlightView.isHighlighted = isHighlighted
      updateSeparatorVisibility()
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
    
    let contentFrame = bounds.inset(by: .contentPadding)
    contentView.frame = contentFrame
    
    listItemView.frame = CGRect(origin: .zero, size: listItemView.sizeThatFits(contentFrame.size))
    
    let bottomContentPadding: CGFloat = 60
    let bottomContentWidth = contentFrame.width - bottomContentPadding
    let bottomContentSize = CGSize(width: bottomContentWidth, height: 0)
    
    statusView.frame = CGRect(
      origin: CGPoint(x: 60, y: listItemView.frame.maxY),
      size: statusView.sizeThatFits(bottomContentSize)
    )
    commentView.frame = CGRect(
      origin: CGPoint(x: 60, y: statusView.frame.maxY),
      size: commentView.sizeThatFits(bottomContentSize)
    )
    descriptionView.frame = CGRect(
      origin: CGPoint(x: 60, y: commentView.frame.maxY),
      size: descriptionView.sizeThatFits(bottomContentSize)
    )
    nftView.frame = CGRect(
      origin: CGPoint(x: 60, y: descriptionView.frame.maxY + 8),
      size: nftView.sizeThatFits(bottomContentSize)
    )
    
    separatorView.frame = CGRect(
      origin: CGPoint(x: 16, y: bounds.height - 0.5),
      size: CGSize(width: bounds.width - 16, height: 0.5)
    )
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {    
    let contentSize = size.inset(by: .contentPadding)
    let listItemViewSize = listItemView.sizeThatFits(contentSize)
    
    let bottomContentPadding: CGFloat = 60
    let bottomContentWidth = contentSize.width - bottomContentPadding
    
    let statusSize = statusView.sizeThatFits(CGSize(width: bottomContentWidth, height: 0))
    let commentSize = commentView.sizeThatFits(CGSize(width: bottomContentWidth, height: 0))
    let descriptionSize = descriptionView.sizeThatFits(CGSize(width: bottomContentWidth, height: 0))
    let nftHeight = nftView.isHidden ? .zero : nftView.sizeThatFits(CGSize(width: bottomContentWidth, height: 0)).height + 8

    let resultHeight = listItemViewSize.height + statusSize.height + commentSize.height + descriptionSize.height + nftHeight
    
    let resultSize = CGSize(width: contentSize.width, height: resultHeight)
      .padding(by: .contentPadding)
    return resultSize
  }
  
  struct Model {
    let listItemModel: HistoryEventActionListItemView.Model
    let statusModel: StatusView.Model
    let commentModel: CommentView.Model?
    let descriptionModel: CommentView.Model?
    let nftModel: NFTView.Model?
  }
  
  func configure(model: Model) {
    listItemView.configure(model: model.listItemModel)
    statusView.configure(model: model.statusModel)
    
    if let commentModel = model.commentModel {
      commentView.configure(model: commentModel)
      commentView.isHidden = false
    } else {
      commentView.isHidden = true
    }
    
    if let descriptionModel = model.descriptionModel {
      descriptionView.configure(model: descriptionModel)
      descriptionView.isHidden = false
    } else {
      descriptionView.isHidden = true
    }
    
    if let nftModel = model.nftModel {
      nftView.configure(model: nftModel)
      nftView.isHidden = false
    } else {
      nftView.isHidden = true
    }
    
    setNeedsLayout()
  }
  
  func prepareForReuse() {
    listItemView.prepareForReuse()
    statusView.prepareForReuse()
    commentView.prepareForReuse()
    descriptionView.prepareForReuse()
    nftView.prepareForReuse()
  }
  
  private func setup() {
    backgroundColor = .Background.content
    isExclusiveTouch = true
    
    highlightView.isUserInteractionEnabled = false
    listItemView.isUserInteractionEnabled = false
    statusView.isUserInteractionEnabled = false
    commentView.isUserInteractionEnabled = false
    descriptionView.isUserInteractionEnabled = false
    
    highlightView.alpha = 1
    addSubview(highlightView)
    addSubview(contentView)
    addSubview(separatorView)
    contentView.addSubview(listItemView)
    contentView.addSubview(statusView)
    contentView.addSubview(commentView)
    contentView.addSubview(descriptionView)
    contentView.addSubview(nftView)
  }
  
  func updateSeparatorVisibility() {
    let isVisible = !isHighlighted && isSeparatorVisible
    separatorView.isHidden = !isVisible
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
