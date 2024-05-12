import UIKit
import TKUIKit

public class SelectionCollectionViewCell: TKCollectionViewNewCell, TKConfigurableView {
  
  public enum AccessoryAlignment {
    case left
    case right
  }
  
  private let listItemView = TKUIListItemView()
  private let accessoryView = SelectionAccessoryView()
  
  private var accesoryAlignment: AccessoryAlignment = .right
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func updateConfiguration(using state: UICellConfigurationState) {
    super.updateConfiguration(using: state)
    
    accessoryView.setIsSelected(state.isSelected, animated: true)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let accessoryViewSize = accessoryView.sizeThatFits(listItemView.bounds.size)
    let accessoryViewPadding = accessoryViewSize.width + .contentHorizontalPadding
    let contentContainerWidth = contentContainerView.bounds.width - accessoryViewPadding
    let accessoryViewY = contentContainerView.bounds.height / 2 - accessoryViewSize.height / 2
    let accessoryViewX: CGFloat
    let listItemViewX: CGFloat
    
    switch accesoryAlignment {
    case .left:
      accessoryViewX = 0
      listItemViewX = accessoryViewPadding
    case .right:
      accessoryViewX = contentContainerWidth + .contentHorizontalPadding
      listItemViewX = 0
    }
    
    let accesoryFrame = CGRect(origin: .init(x: accessoryViewX, y: accessoryViewY), size: accessoryViewSize)
    let listItemFrame = CGRect(
      x: listItemViewX,
      y: 0,
      width: contentContainerWidth,
      height: contentContainerView.bounds.height
    )
    
    accessoryView.frame = accesoryFrame
    listItemView.frame = listItemFrame
  }
  
  public override func contentSize(targetWidth: CGFloat) -> CGSize {
    listItemView.sizeThatFits(CGSize(width: targetWidth, height: 0))
  }
  
  public struct Configuration: Hashable {
    public let id: String
    public let listItemConfiguration: TKUIListItemView.Configuration
    public let accesoryConfiguration: SelectionAccessoryView.Configuration
    public let accesoryAlignment: AccessoryAlignment
    public let selectionClosure: (() -> Void)?
    
    init(id: String, 
         listItemConfiguration: TKUIListItemView.Configuration,
         accesoryConfiguration: SelectionAccessoryView.Configuration,
         accesoryAlignment: AccessoryAlignment,
         selectionClosure: (() -> Void)?) {
      self.id = id
      self.listItemConfiguration = listItemConfiguration
      self.accesoryConfiguration = accesoryConfiguration
      self.accesoryAlignment = accesoryAlignment
      self.selectionClosure = selectionClosure
    }
    
    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
      hasher.combine(listItemConfiguration)
      hasher.combine(accesoryConfiguration)
      hasher.combine(accesoryAlignment)
    }
    
    public static func ==(lhs: Configuration, rhs: Configuration) -> Bool {
      lhs.id == rhs.id 
      && lhs.listItemConfiguration == rhs.listItemConfiguration
      && lhs.accesoryConfiguration == rhs.accesoryConfiguration
      && lhs.accesoryAlignment == rhs.accesoryAlignment
    }
  }
  
  public func configure(configuration: Configuration) {
    listItemView.configure(configuration: configuration.listItemConfiguration)
    accessoryView.configure(configuration: configuration.accesoryConfiguration)
    accesoryAlignment = configuration.accesoryAlignment
    setNeedsLayout()
  }
}

private extension SelectionCollectionViewCell {
  func setup() {
    backgroundColor = .Background.content
    hightlightColor = .Background.highlighted
    contentViewPadding = .init(top: 16, left: 16, bottom: 16, right: 16)
    contentContainerView.addSubview(listItemView)
    contentContainerView.addSubview(accessoryView)
  }
}

private extension CGFloat {
  static let contentHorizontalPadding: CGFloat = 16
}
