import UIKit
import TKUIKit

public final class WalletBalanceListCell: TKCollectionViewNewCell, ConfigurableView {
  let listItemView = TKUIListItemView()
  let commentView = TKCommentView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Model {
    public let listItemConfiguration: TKUIListItemView.Configuration
    public let commentConfiguration: TKCommentView.Model?
    public let selectionClosure: (() -> Void)?
    
    public init(listItemConfiguration: TKUIListItemView.Configuration,
                commentConfiguration: TKCommentView.Model? = nil,
                selectionClosure: (() -> Void)? ) {
      self.listItemConfiguration = listItemConfiguration
      self.commentConfiguration = commentConfiguration
      self.selectionClosure = selectionClosure
    }
  }
  
  public func configure(model: Model) {
    listItemView.configure(configuration: model.listItemConfiguration)
    if let commentConfiguration = model.commentConfiguration {
      commentView.configure(model: commentConfiguration)
      commentView.isHidden = false
    } else {
      commentView.prepareForReuse()
      commentView.isHidden = true
    }
    
    setNeedsLayout()
  }
  
  public override func contentSize(targetWidth: CGFloat) -> CGSize {
    let listItemSize = listItemView.sizeThatFits(CGSize(width: targetWidth, height: 0))
    let commentSize: CGSize
    if commentView.isHidden {
      commentSize = .zero
    } else {
      commentSize = commentView.sizeThatFits(CGSize(width: targetWidth - .commentViewLeftInset, height: 0))
    }
    let height = listItemSize.height + commentSize.height
    return CGSize(width: targetWidth, height: height)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    let listItemSize = listItemView.sizeThatFits(CGSize(width: contentContainerView.bounds.width, height: 0))
    listItemView.frame = CGRect(origin: .zero, size: listItemSize)
    
    if !commentView.isHidden {
      commentView.frame = CGRect(
        origin: CGPoint(x: .commentViewLeftInset, y: listItemView.frame.maxY),
        size: commentView.sizeThatFits(CGSize(width: contentContainerView.bounds.width - .commentViewLeftInset, height: 0))
      )
    } else {
      commentView.frame = CGRect(
        origin: CGPoint(x: 0, y: listItemView.frame.maxY),
        size: .zero)
    }
  }
}

private extension WalletBalanceListCell {
  func setup() {
    backgroundColor = .Background.content
    hightlightColor = .Background.highlighted
    contentViewPadding = .init(top: 16, left: 16, bottom: 16, right: 16)
    contentContainerView.addSubview(listItemView)
    contentContainerView.addSubview(commentView)
  }
}

private extension CGFloat {
  static let commentViewLeftInset: CGFloat = 60
}
