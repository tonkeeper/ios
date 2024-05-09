import UIKit
import TKUIKit

public class RadioButtonCollectionViewCell: TKCollectionViewNewCell, TKConfigurableView {
  let listItemView = TKUIListItemView()
  let radioButtonView = RadioButtonView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func updateConfiguration(using state: UICellConfigurationState) {
    super.updateConfiguration(using: state)
    
    UIView.animate(withDuration: 0.15) {
      self.radioButtonView.setIsSelected(state.isSelected)
    }
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let radioButtonSize = radioButtonView.sizeThatFits(listItemView.bounds.size)
    let radioButtonPadding = radioButtonSize.width + .contentHorizontalPadding
    let contentContainerWidth = contentContainerView.bounds.width - radioButtonPadding
    let radioButtonY = contentContainerView.bounds.height / 2 - radioButtonSize.height / 2
    let radioButtonX: CGFloat
    let listItemViewX: CGFloat
    
    switch radioButtonView.alignment {
    case .left:
      radioButtonX = 0
      listItemViewX = radioButtonPadding
    case .right:
      radioButtonX = contentContainerWidth + .contentHorizontalPadding
      listItemViewX = 0
    }
    
    let radioButtonFrame = CGRect(origin: .init(x: radioButtonX, y: radioButtonY), size: radioButtonSize)
    let listItemFrame = CGRect(
      x: listItemViewX,
      y: 0,
      width: contentContainerWidth,
      height: contentContainerView.bounds.height
    )
    
    radioButtonView.frame = radioButtonFrame
    listItemView.frame = listItemFrame
  }
  
  public override func contentSize(targetWidth: CGFloat) -> CGSize {
    listItemView.sizeThatFits(CGSize(width: targetWidth, height: 0))
  }
  
  public struct Configuration: Hashable {
    public let id: String
    public let listItemConfiguration: TKUIListItemView.Configuration
    public let radioButtonAlignment: RadioButtonView.Alignment
  }
  
  public func configure(configuration: Configuration) {
    listItemView.configure(configuration: configuration.listItemConfiguration)
    radioButtonView.configure(configuration: .init(isSelected: false, alignment: configuration.radioButtonAlignment))
    setNeedsLayout()
  }
}

private extension RadioButtonCollectionViewCell {
  func setup() {
    backgroundColor = .Background.content
    hightlightColor = .Background.highlighted
    contentViewPadding = .init(top: 16, left: 16, bottom: 16, right: 16)
    contentContainerView.addSubview(listItemView)
    contentContainerView.addSubview(radioButtonView)
  }
}

private extension CGFloat {
  static let contentHorizontalPadding: CGFloat = 16
}
