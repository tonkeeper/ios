import UIKit

public final class TKListItemCell: TKCollectionViewListCell {
  public struct Configuration {
    public let listItemContentViewConfiguration: TKListItemContentView.Configuration
    
    public init(listItemContentViewConfiguration: TKListItemContentView.Configuration) {
      self.listItemContentViewConfiguration = listItemContentViewConfiguration
    }
    
    public static var `default`: Configuration {
      Configuration(listItemContentViewConfiguration: .default)
    }
  }
  
  let listItemContentView = TKListItemContentView()
  
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
    
    setContentView(listItemContentView)
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
  
  public override func prepareForReuse() {
    super.prepareForReuse()
    listItemContentView.prepareForReuse()
  }
  
  private func didUpdateConfiguration() {
    listItemContentView.configuration = configuration.listItemContentViewConfiguration
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
