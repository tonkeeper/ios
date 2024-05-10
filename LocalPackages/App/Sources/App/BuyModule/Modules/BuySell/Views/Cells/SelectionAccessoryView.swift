import UIKit
import TKUIKit

public final class SelectionAccessoryView: UIView, TKConfigurableView, ReusableView {
  
  public enum AccessoryType {
    case checkmark
    case radioButton
  }
  
  private let imageView = UIImageView()
  
  private let size: CGSize = .accessoryItemSize
  private var accessoryType: AccessoryType = .checkmark
  
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
    imageView.tintColor = nil
  }
  
  public struct Configuration: Hashable {
    public let accessoryType: AccessoryType
  }
  
  public func configure(configuration: Configuration) {
    accessoryType = configuration.accessoryType
    imageView.image = accessoryType.image(isSelected: false)
    imageView.tintColor = accessoryType.tintColor(isSelected: false)
  }
  
  public func setIsSelected(_ isSelected: Bool, animated: Bool) {
    if animated, accessoryType == .radioButton {
      UIView.animate(withDuration: 0.15) {
        self.setIsSelected(isSelected)
      }
    } else {
      setIsSelected(isSelected)
    }
  }
  
  public func setIsSelected(_ isSelected: Bool) {
    switch accessoryType {
    case .checkmark:
      imageView.alpha = isSelected ? 1 : 0
    case .radioButton:
      imageView.image = AccessoryType.radioButton.image(isSelected: isSelected)
      imageView.tintColor = AccessoryType.radioButton.tintColor(isSelected: isSelected)
    }
  }
}

private extension SelectionAccessoryView {
  func setup() {
    layer.masksToBounds = true
    
    imageView.contentMode = .center
    addSubview(imageView)
  }
}

private extension CGSize {
  static let accessoryItemSize = CGSize(width: 28, height: 28)
}

private extension SelectionAccessoryView.AccessoryType {
  func image(isSelected: Bool) -> UIImage? {
    switch self {
    case .checkmark:
      return .checkmarkIconEnabled
    case .radioButton:
      return isSelected ? .radioButtonIconEnabled : .radioButtonIconDisabled
    }
  }
  
  func tintColor(isSelected: Bool) -> UIColor? {
    switch self {
    case .checkmark:
      return .Button.primaryBackground
    case .radioButton:
      return isSelected ? .Button.primaryBackground : .Button.tertiaryBackground
    }
  }
}

private extension UIImage {
  static let checkmarkIconEnabled = UIImage.TKUIKit.Icons.Size28.donemarkOutline
  static let radioButtonIconEnabled = UIImage.TKUIKit.Icons.Size28.radioButtonEnabled
  static let radioButtonIconDisabled = UIImage.TKUIKit.Icons.Size28.radioButtonDisabled
}
