import UIKit
import TKUIKit

public final class RadioButtonView: UIView, TKConfigurableView, ReusableView {
  public enum Alignment {
    case left
    case right
  }
  
  private let imageView = UIImageView()
  
  private let size: CGSize = .radioButtonSize
  public var alignment: Alignment = .right
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required public  init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    imageView.frame = bounds
    layer.cornerRadius = bounds.width / 2
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    self.size
  }
  
  public func prepareForReuse() {
    imageView.image = nil
  }
  
  public struct Configuration: Hashable {
    public let isSelected: Bool
    public let alignment: Alignment
  }
  
  public func configure(configuration: Configuration) {
    setIsSelected(configuration.isSelected)
    alignment = configuration.alignment
  }
  
  public func setIsSelected(_ isSelected: Bool) {
    imageView.image = radioButtonIconImage(isSelected: isSelected)
    imageView.tintColor = radioButtonIconTintColor(isSelected: isSelected)
  }
}

private extension RadioButtonView {
  func setup() {
    layer.masksToBounds = true
    
    imageView.contentMode = .center
    addSubview(imageView)
  }
  
  func radioButtonIconImage(isSelected: Bool) -> UIImage {
    return isSelected ? .radioButtonIconEnabled : .radioButtonIconDisabled
  }
  
  func radioButtonIconTintColor(isSelected: Bool) -> UIColor {
    return isSelected ? .Button.primaryBackground : .Button.tertiaryBackground
  }
}

private extension CGSize {
  static let radioButtonSize = CGSize(width: 28, height: 28)
}

private extension UIImage {
  static let radioButtonIconEnabled = UIImage.TKUIKit.Icons.Size28.radioButtonEnabled
  static let radioButtonIconDisabled = UIImage.TKUIKit.Icons.Size28.radioButtonDisabled
}
