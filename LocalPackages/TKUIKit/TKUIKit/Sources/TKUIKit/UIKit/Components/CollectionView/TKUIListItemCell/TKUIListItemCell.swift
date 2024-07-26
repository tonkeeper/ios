import UIKit

public class TKUIListItemCell: TKCollectionViewNewCell, TKConfigurableView {
  let listItemView = TKUIListItemView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Configuration: Hashable {
    public let id: String
    public let listItemConfiguration: TKUIListItemView.Configuration
    public let isHighlightable: Bool
    public let selectionClosure: (() -> Void)?
    
    public init(id: String, 
                listItemConfiguration: TKUIListItemView.Configuration,
                isHighlightable: Bool = true,
                selectionClosure: (() -> Void)? ) {
      self.id = id
      self.isHighlightable = isHighlightable
      self.listItemConfiguration = listItemConfiguration
      self.selectionClosure = selectionClosure
    }
    
    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
      hasher.combine(listItemConfiguration)
    }
    
    public static func ==(lhs: Configuration, rhs: Configuration) -> Bool {
      lhs.id == rhs.id && lhs.listItemConfiguration == rhs.listItemConfiguration
    }
  }
  
  public func configure(configuration: Configuration) {
    isHighlightable = configuration.isHighlightable
    listItemView.configure(configuration: configuration.listItemConfiguration)
    setNeedsLayout()
  }
  
  public override func contentSize(targetWidth: CGFloat) -> CGSize {
    listItemView.sizeThatFits(CGSize(width: targetWidth, height: 0))
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    listItemView.frame = contentContainerView.bounds
  }
  
  public override func prepareForReuse() {
    super.prepareForReuse()
    listItemView.prepareForReuse()
  }
}

private extension TKUIListItemCell {
  func setup() {
    backgroundColor = .Background.content
    hightlightColor = .Background.highlighted
    contentViewPadding = .init(top: 16, left: 16, bottom: 16, right: 16)
    contentContainerView.addSubview(listItemView)
  }
}
