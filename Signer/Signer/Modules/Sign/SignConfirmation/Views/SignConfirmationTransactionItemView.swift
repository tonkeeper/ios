import UIKit
import TKUIKit

final class SignConfirmationTransactionItemView: UIView, ConfigurableView {
  var isSeparatorVisible: Bool = true {
      didSet {
        updateSeparatorVisibility()
      }
    }
  
  let highlightView = TKHighlightView()
  let contentContainer = TKPassthroughView()
  let iconView = IconView()
  let contentView = TKUIListItemContentView()
  let commentView = SignConfirmationTransactionItemCommentView()
  let separatorView = TKSeparatorView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let iconConfiguration: IconView.Configuration
    let contentConfiguration: TKUIListItemContentView.Configuration
    let commentConfiguration: SignConfirmationTransactionItemCommentView.Model?
  }
  
  func configure(model: Model) {
    iconView.configure(configuration: model.iconConfiguration)
    contentView.configure(configuration: model.contentConfiguration)
    if let commentConfiguration = model.commentConfiguration {
      commentView.isHidden = false
      commentView.configure(model: commentConfiguration)
    } else {
      commentView.isHidden = true
    }
    setNeedsLayout()
    invalidateIntrinsicContentSize()
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let contentSize = size.inset(by: .contentPadding)
    let iconViewSizeThatFits = iconView.sizeThatFits(contentSize)
    
    var contentViewWidth = contentSize.width
    if !iconViewSizeThatFits.width.isZero {
      contentViewWidth -= iconViewSizeThatFits.width + 16
    }
    
    let contentSizeThatFits = contentView.sizeThatFits(CGSize(width: contentViewWidth, height: 0))

    let commentSize: CGSize
    if commentView.isHidden {
      commentSize = .zero
    } else {
      commentSize = commentView.sizeThatFits(CGSize(width: contentViewWidth, height: 0))
    }
    let height = contentSizeThatFits.height
    + commentSize.height
    + UIEdgeInsets.contentPadding.top
    + UIEdgeInsets.contentPadding.bottom
    
    return CGSize(width: size.width, height: height)
  }
  
  override var intrinsicContentSize: CGSize {
    return CGSize(width: UIView.noIntrinsicMetric, height: sizeThatFits(.init(width: bounds.width, height: 0)).height)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    highlightView.frame = bounds
    
    let contentFrame = bounds.inset(by: .contentPadding)
    contentContainer.frame = contentFrame
    
    iconView.sizeToFit()
    iconView.frame.origin = CGPoint(
      x: 0,
      y: 0
    )
    
    var contentViewWidth = contentFrame.width
    var contentViewX: CGFloat = 0
    if !iconView.frame.width.isZero {
      contentViewWidth -= iconView.frame.width + 16
      contentViewX = iconView.frame.maxX + 16
    }
    
    let contentSizeThatFits = contentView.sizeThatFits(CGSize(width: contentViewWidth, height: 0))
    
    contentView.frame = CGRect(x: contentViewX, y: 0, width: contentViewWidth, height: contentSizeThatFits.height)

    if !commentView.isHidden {
      commentView.frame = CGRect(
        origin: CGPoint(x: contentViewX, y: contentView.frame.maxY),
        size: commentView.sizeThatFits(CGSize(width: contentViewWidth, height: 0))
      )
    } else {
      commentView.frame = CGRect(
        origin: CGPoint(x: contentViewX, y: contentView.frame.maxY),
        size: .zero)
    }
    
    separatorView.frame = CGRect(
      x: UIEdgeInsets.contentPadding.left,
      y: bounds.height - 0.5,
      width: bounds.width - UIEdgeInsets.contentPadding.left,
      height: 0.5
    )
  }
  
  func prepareForReuse() {
//    nftView.prepareForReuse()
  }
  
  func updateSeparatorVisibility() {
    separatorView.isHidden = !isSeparatorVisible
  }
}

private extension SignConfirmationTransactionItemView {
  func setup() {
    iconView.isUserInteractionEnabled = false
    contentView.isUserInteractionEnabled = false
    
    separatorView.color = .Separator.common
    backgroundColor = .Background.content
    
    addSubview(highlightView)
    addSubview(contentContainer)
    contentContainer.addSubview(iconView)
    contentContainer.addSubview(contentView)
    contentContainer.addSubview(commentView)
    addSubview(separatorView)
  }
}

private extension UIEdgeInsets {
  static var contentPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
}

extension SignConfirmationTransactionItemView {
  final class IconView: UIView, TKConfigurableView {
    private let imageView = TKUIListItemImageIconView()
    
    override init(frame: CGRect) {
      super.init(frame: frame)
      setup()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    struct Configuration: Hashable {
      let imageModel: TKUIListItemImageIconView.Configuration
    }
    
    func configure(configuration: Configuration) {
      imageView.configure(configuration: configuration.imageModel)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
      return imageView.sizeThatFits(size)
    }
    
    public override func layoutSubviews() {
      super.layoutSubviews()
      imageView.frame = bounds
    }
  }
}

private extension SignConfirmationTransactionItemView.IconView {
  func setup() {
    addSubview(imageView)
  }
}
