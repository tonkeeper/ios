import UIKit
import TKUIKit

public final class WalletBalanceListCell: TKCollectionViewListCell {
  public struct Configuration {
    public let walletBalanceListCellContentViewConfiguration: WalletBalanceListCellContentView.Configuration
    
    public init(walletBalanceListCellContentViewConfiguration: WalletBalanceListCellContentView.Configuration) {
      self.walletBalanceListCellContentViewConfiguration = walletBalanceListCellContentViewConfiguration
    }
    
    public static var `default`: Configuration {
      Configuration(
        walletBalanceListCellContentViewConfiguration: WalletBalanceListCellContentView.Configuration(
          listItemContentViewConfiguration: .default,
          commentViewConfiguration: nil
        )
      )
    }
  }
  
  public let walletBalanceListCellContentView = WalletBalanceListCellContentView()
  
  public var configuration: Configuration = .default {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .Background.content
    
    let highlightView = UIView()
    highlightView.backgroundColor = .Background.highlighted
    self.highlightView = highlightView
    
    layer.cornerRadius = 16
    
    setContentView(walletBalanceListCellContentView)
    listCellContentViewPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    didUpdateConfiguration()
  }
  
  public override func didUpdateCellOrderInSection() {
    super.didUpdateCellOrderInSection()
    updateCornerRadius()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func didUpdateConfiguration() {
    walletBalanceListCellContentView.configuration = configuration.walletBalanceListCellContentViewConfiguration
  }
  
  private func updateCornerRadius() {
    let maskedCorners: CACornerMask
    let isMasksToBounds: Bool
    switch (isFirst, isLast) {
    case (true, true):
      maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
      isMasksToBounds = true
    case (false, true):
      maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
      isMasksToBounds = true
    case (true, false):
      maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
      isMasksToBounds = true
    case (false, false):
      maskedCorners = []
      isMasksToBounds = false
    }
    layer.maskedCorners = maskedCorners
    layer.masksToBounds = isMasksToBounds
  }
}

public final class WalletBalanceListCellContentView: UIView {
  
  public struct Configuration {
    public let listItemContentViewConfiguration: TKListItemContentViewV2.Configuration
    public let commentViewConfiguration: TKCommentView.Model?
    
    public init(listItemContentViewConfiguration: TKListItemContentViewV2.Configuration,
                commentViewConfiguration: TKCommentView.Model? = nil) {
      self.listItemContentViewConfiguration = listItemContentViewConfiguration
      self.commentViewConfiguration = commentViewConfiguration
    }
    
    public static var `default`: Configuration {
      Configuration(listItemContentViewConfiguration: .default,
                    commentViewConfiguration: nil)
    }
  }
  
  public var configuration = Configuration.default {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  let listItemContentView = TKListItemContentViewV2()
  let commentView = TKCommentView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    let listItemSize = listItemContentView.sizeThatFits(CGSize(width: bounds.width, height: 0))
    listItemContentView.frame = CGRect(origin: .zero, size: listItemSize)
    
    if !commentView.isHidden {
      commentView.frame = CGRect(
        origin: CGPoint(x: .commentViewLeftInset, y: listItemContentView.frame.maxY),
        size: commentView.sizeThatFits(CGSize(width: bounds.width - .commentViewLeftInset, height: 0))
      )
    } else {
      commentView.frame = CGRect(
        origin: CGPoint(x: 0, y: listItemContentView.frame.maxY),
        size: .zero)
    }
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    super.sizeThatFits(size)
    
    let listItemSize = listItemContentView.sizeThatFits(CGSize(width: size.width, height: 0))
    
    let commentSize: CGSize
    if commentView.isHidden {
      commentSize = .zero
    } else {
      commentSize = commentView.sizeThatFits(CGSize(width: size.width - .commentViewLeftInset, height: 0))
    }
    let height = listItemSize.height + commentSize.height
    return CGSize(width: size.width, height: height)
  }
  
  private func setup() {
    addSubview(listItemContentView)
    addSubview(commentView)
    
    didUpdateConfiguration()
  }
  
  private func didUpdateConfiguration() {
    listItemContentView.configuration = configuration.listItemContentViewConfiguration
  
    if let commentViewConfiguration = configuration.commentViewConfiguration {
      commentView.isHidden = false
      commentView.configure(model: commentViewConfiguration)
    } else {
      commentView.isHidden = true
    }
  }
}

private extension CGFloat {
  static let commentViewLeftInset: CGFloat = 60
}
