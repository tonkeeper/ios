import UIKit
import TKUIKit

final class SettingsCellIconValueView: UIView, ConfigurableView, ReusableView {
  
  private let imageView = UIImageView()
  
  private var size: CGSize = .zero
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public  init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    imageView.frame = bounds
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    self.size
  }
  
  public func prepareForReuse() {
    imageView.image = nil
  }

  public struct Model {
    public let image: UIImage?
    public let tintColor: UIColor
    public let backgroundColor: UIColor
    public let size: CGSize
    
    public init(image: UIImage?,
                tintColor: UIColor,
                backgroundColor: UIColor,
                size: CGSize) {
      self.image = image
      self.tintColor = tintColor
      self.backgroundColor = backgroundColor
      self.size = size
    }
  }
  
  public func configure(model: Model) {
    imageView.image = model.image
    imageView.tintColor = model.tintColor
    backgroundColor = model.backgroundColor
    size = model.size
  }
}

private extension SettingsCellIconValueView {
  func setup() {
    imageView.contentMode = .center
    addSubview(imageView)
  }
}

