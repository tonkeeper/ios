import UIKit
import TKUIKit

final class HistoryCellActionView: UIControl, ConfigurableView, ReusableView {
  var isSeparatorVisible: Bool = true {
      didSet {
        updateSeparatorVisibility()
      }
    }
  
  let highlightView = TKHighlightView()
  let contentContainer = TKPassthroughView()
  let iconView = HistoryCellIconView()
  let contentView = TKUIListItemContentView()
  let commentView = CommentView()
  let encryptedCommentView = EncyptedCommentView()
  let descriptionView = CommentView()
  let nftView = NFTView()
  let separatorView = TKSeparatorView()
  let inProgressLoaderView = HistoryCellLoaderView()
  
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
  
  struct Model {
    let iconConfiguration: HistoryCellIconView.Configuration
    let contentConfiguration: TKUIListItemContentView.Configuration
    let commentConfiguration: CommentView.Configuration?
    let encryptedCommentConfiguration: EncyptedCommentView.Model?
    let descriptionConfiguration: CommentView.Configuration?
    let nftConfiguration: NFTView.Configuration?
    let isInProgress: Bool
  }
  
  func configure(model: Model) {
    iconView.configure(configuration: model.iconConfiguration)
    contentView.configure(configuration: model.contentConfiguration)
    if let commentConfiguration = model.commentConfiguration {
      commentView.isHidden = false
      commentView.configure(configuration: commentConfiguration)
    } else {
      commentView.isHidden = true
    }
    
    if let encryptedCommentConfiguration = model.encryptedCommentConfiguration {
      encryptedCommentView.isHidden = false
      encryptedCommentView.configure(model: encryptedCommentConfiguration)
    } else {
      encryptedCommentView.isHidden = true
    }
    
    if let descriptionConfiguration = model.descriptionConfiguration {
      descriptionView.isHidden = false
      descriptionView.configure(configuration: descriptionConfiguration)
    } else {
      descriptionView.isHidden = true
    }
    
    if let nftConfiguration = model.nftConfiguration {
      nftView.isHidden = false
      nftView.configure(configuration: nftConfiguration)
    } else {
      nftView.isHidden = true
    }
    
    if model.isInProgress {
      inProgressLoaderView.isHidden = false
      inProgressLoaderView.startAnimation()
    } else {
      inProgressLoaderView.isHidden = true
      inProgressLoaderView.stopAnimation()
    }
    
    setNeedsLayout()
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
    
    let encryptedCommentSize: CGSize
    if encryptedCommentView.isHidden {
      encryptedCommentSize = .zero
    } else {
      encryptedCommentSize = encryptedCommentView.sizeThatFits(CGSize(width: contentViewWidth, height: 0))
    }
    
    let descriptionSize: CGSize
    if descriptionView.isHidden {
      descriptionSize = .zero
    } else {
      descriptionSize = descriptionView.sizeThatFits(CGSize(width: contentViewWidth, height: 0))
    }
    
    let nftSize: CGSize
    if nftView.isHidden {
      nftSize = .zero
    } else {
      nftSize = nftView.sizeThatFits(CGSize(width: contentViewWidth, height: 0))
    }
    
    let height = contentSizeThatFits.height
    + commentSize.height
    + encryptedCommentSize.height
    + descriptionSize.height
    + nftSize.height
    + UIEdgeInsets.contentPadding.top
    + UIEdgeInsets.contentPadding.bottom
    
    return CGSize(width: size.width, height: height)
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
    
    if !nftView.isHidden {
      nftView.frame = CGRect(
        origin: CGPoint(x: contentViewX, y: contentView.frame.maxY),
        size: nftView.sizeThatFits(CGSize(width: contentViewWidth, height: 0))
      )
    } else {
      nftView.frame = CGRect(
        origin: CGPoint(x: contentViewX, y: contentView.frame.maxY),
        size: .zero)
    }
    
    if !commentView.isHidden {
      commentView.frame = CGRect(
        origin: CGPoint(x: contentViewX, y: nftView.frame.maxY),
        size: commentView.sizeThatFits(CGSize(width: contentViewWidth, height: 0))
      )
    } else {
      commentView.frame = CGRect(
        origin: CGPoint(x: contentViewX, y: nftView.frame.maxY),
        size: .zero)
    }
    
    if !encryptedCommentView.isHidden {
      encryptedCommentView.frame = CGRect(
        origin: CGPoint(x: contentViewX, y: commentView.frame.maxY),
        size: encryptedCommentView.sizeThatFits(CGSize(width: contentViewWidth, height: 0))
      )
    } else {
      encryptedCommentView.frame = CGRect(
        origin: CGPoint(x: contentViewX, y: commentView.frame.maxY),
        size: .zero)
    }
    
    if !descriptionView.isHidden {
      descriptionView.frame = CGRect(
        origin: CGPoint(x: contentViewX, y: encryptedCommentView.frame.maxY),
        size: descriptionView.sizeThatFits(CGSize(width: contentViewWidth, height: 0))
      )
    } else {
      descriptionView.frame = CGRect(
        origin: CGPoint(x: contentViewX, y: encryptedCommentView.frame.maxY),
        size: .zero)
    }
    
    separatorView.frame = CGRect(
      x: UIEdgeInsets.contentPadding.left,
      y: bounds.height - 0.5,
      width: bounds.width - UIEdgeInsets.contentPadding.left,
      height: 0.5
    )
    
    inProgressLoaderView.sizeToFit()
    inProgressLoaderView.frame.origin = CGPoint(
      x: iconView.frame.minX - 3,
      y: iconView.frame.minY - 3
    )
  }
  
  func prepareForReuse() {
    nftView.prepareForReuse()
  }
  
  func updateSeparatorVisibility() {
    let isVisible = !isHighlighted && isSeparatorVisible
    separatorView.isHidden = !isVisible
  }
}

private extension HistoryCellActionView {
  func setup() {
    iconView.isUserInteractionEnabled = false
    contentView.isUserInteractionEnabled = false
    commentView.isUserInteractionEnabled = false
    descriptionView.isUserInteractionEnabled = false
    
    separatorView.color = .Separator.common
    backgroundColor = .Background.content
    isExclusiveTouch = true
    
    addSubview(highlightView)
    addSubview(contentContainer)
    contentContainer.addSubview(iconView)
    contentContainer.addSubview(contentView)
    contentContainer.addSubview(encryptedCommentView)
    contentContainer.addSubview(commentView)
    contentContainer.addSubview(descriptionView)
    contentContainer.addSubview(nftView)
    contentContainer.addSubview(inProgressLoaderView)
    addSubview(separatorView)
  }
}

private extension UIEdgeInsets {
  static var contentPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
}
