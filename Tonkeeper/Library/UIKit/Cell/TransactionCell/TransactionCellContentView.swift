//
//  TransactionCellContentView.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

protocol TransactionCellContentViewDelegate: AnyObject {
  func transactionCellDidTapNFTView(_ transactionCell: TransactionCellContentView)
}

final class TransactionCellContentView: UIControl, ContainerCollectionViewCellContent {
  
  weak var delegate: TransactionCellContentViewDelegate?
  
  override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue else { return }
      didUpdateHightlightState()
    }
  }
  
  var isSeparatorVisible: Bool = true {
    didSet {
      updateSeparatorVisibility()
    }
  }

  let contentView = PassthroughView()
  let defaultCellContentView = DefaultCellContentView()
  let statusView = TransactionCellStatusView()
  let commentView = TransactionCellCommentView()
  let nftView = TransactionCellNFTView()
  let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  
  struct Model {
    let defaultContentModel: DefaultCellContentView.Model
    let statusModel: TransactionCellStatusView.Model?
    let commentModel: TransactionCellCommentView.Model?
    let nftModel: TransactionCellNFTView.Model?
  }
  
  weak var imageLoader: ImageLoader? {
    didSet { nftView.imageLoader = imageLoader }
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
    let contentViewSize = CGSize(width: bounds.width - ContentInsets.sideSpace * 2,
                                 height: max(0, bounds.height - ContentInsets.sideSpace * 2))
    let defaultCellContentSize = defaultCellContentView.sizeThatFits(.init(width: contentViewSize.width, height: 0))
    defaultCellContentView.frame.size = defaultCellContentSize
    defaultCellContentView.frame.origin = .zero
    
    var bottomContentY = defaultCellContentView.frame.maxY
    
    let statusSize = statusView.sizeThatFits(.init(width: contentViewSize.width, height: 0))
    statusView.frame = CGRect(x: defaultCellContentView.textContentFrame.minX,
                              y: bottomContentY,
                              width: defaultCellContentView.textContentFrame.width,
                              height: statusSize.height)
    
    
    bottomContentY = statusView.frame.maxY
    
    let commentSize = commentView.sizeThatFits(.init(width: contentViewSize.width - .additionalContentLeftSpacing, height: 0))
    commentView.frame = CGRect(x: defaultCellContentView.textContentFrame.minX,
                               y: bottomContentY,
                               width: commentSize.width,
                               height: commentSize.height)
    bottomContentY = commentView.frame.maxY
    
    let nftSize = nftView.sizeThatFits(.init(width: contentViewSize.width, height: 0))
    nftView.frame = CGRect(x: defaultCellContentView.textContentFrame.minX,
                           y: bottomContentY,
                           width: min(nftSize.width, contentViewSize.width),
                           height: nftSize.height)
    
    contentView.frame.size = contentViewSize
    contentView.frame.origin = CGPoint(x: ContentInsets.sideSpace, y: ContentInsets.sideSpace)
    
    separatorView.frame = CGRect(
      x: ContentInsets.sideSpace,
      y: bounds.height - .separatorHeight, width
      : bounds.width - ContentInsets.sideSpace,
      height: .separatorHeight)
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let contentViewSize = CGSize(width: size.width - ContentInsets.sideSpace * 2,
                                 height: max(0, size.height - ContentInsets.sideSpace * 2))
    let defaultCellContentHeight = defaultCellContentView.sizeThatFits(contentViewSize).height
    let statusHeight = statusView.sizeThatFits(contentViewSize).height
    let commentHeight = commentView.sizeThatFits(.init(width: contentViewSize.width - .additionalContentLeftSpacing, height: 0)).height
    let nftHeight = nftView.sizeThatFits(contentViewSize).height
    let height = defaultCellContentHeight + statusHeight + commentHeight + nftHeight + ContentInsets.sideSpace * 2
    return .init(width: size.width, height: height)
  }
  
  func configure(model: Model) {
    defaultCellContentView.configure(model: model.defaultContentModel)
    
    if let statusModel = model.statusModel {
      statusView.configure(model: statusModel)
      statusView.isHidden = false
    } else {
      statusView.isHidden = true
    }
    
    if let commentModel = model.commentModel {
      commentView.configure(model: commentModel)
      commentView.isHidden = false
    } else {
      commentView.isHidden = true
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
    defaultCellContentView.prepareForReuse()
    statusView.prepareForReuse()
    commentView.prepareForReuse()
    nftView.prepareForReuse()
  }
}

private extension TransactionCellContentView {
  func setup() {
    isExclusiveTouch = true
    defaultCellContentView.isUserInteractionEnabled = false
    statusView.isUserInteractionEnabled = false
    commentView.isUserInteractionEnabled = false

    addSubview(contentView)
    addSubview(separatorView)
    contentView.addSubview(defaultCellContentView)
    contentView.addSubview(statusView)
    contentView.addSubview(commentView)
    contentView.addSubview(nftView)
    
    nftView.addTarget(
      self,
      action: #selector(didTapNFTView),
      for: .touchUpInside
    )
  }
  
  func didUpdateHightlightState() {
    let duration: TimeInterval = isHighlighted ? 0.05 : 0.2
    
    updateSeparatorVisibility()
    UIView.animate(withDuration: duration, delay: 0, options: [.allowUserInteraction, .curveEaseInOut]) {
      self.backgroundColor = self.isHighlighted ? .Background.highlighted : .Background.content
    }
  }
  
  func updateSeparatorVisibility() {
    let isVisible = !isHighlighted && isSeparatorVisible
    separatorView.isHidden = !isVisible
  }
  
  @objc
  func didTapNFTView() {
    delegate?.transactionCellDidTapNFTView(self)
  }
}

private extension CGFloat {
  static let additionalContentLeftSpacing: CGFloat = 60
  static let separatorHeight: CGFloat = 0.5
}
