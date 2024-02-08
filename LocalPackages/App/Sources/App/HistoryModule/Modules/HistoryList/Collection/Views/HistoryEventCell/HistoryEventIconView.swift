import UIKit
import TKUIKit

final class HistoryEventIconView: UIView, ConfigurableView, ReusableView {
  
  private let imageView = UIImageView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public  init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    imageView.frame = CGRect(origin: .zero, size: .size)
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    .size
  }
  
  func prepareForReuse() {
    imageView.image = nil
  }

  struct Model {
    let image: UIImage?
    let isInProgress: Bool
  }
  
  func configure(model: Model) {
    imageView.image = model.image
  }
}

private extension HistoryEventIconView {
  func setup() {
    imageView.contentMode = .center
    imageView.backgroundColor = .Background.contentTint
    imageView.layer.masksToBounds = true
    imageView.layer.cornerRadius = .cornerRadius
    imageView.tintColor = .Icon.secondary
    addSubview(imageView)
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 22
}

private extension CGSize {
  static let size = CGSize(width: 44, height: 44)
}
