import UIKit

public final class TKUIHeaderButtonIconContentView: UIView, ConfigurableView {
  let iconImageView = UIImageView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Model {
    let image: UIImage
    
    public init(image: UIImage) {
      self.image = image
    }
  }
  
  public func configure(model: Model) {
    iconImageView.image = model.image
  }
  
  public func setForegroundColor(_ color: UIColor) {
    iconImageView.tintColor = color
  }
}

private extension TKUIHeaderButtonIconContentView {
  func setup() {
    setContentHuggingPriority(.required, for: .horizontal)
    setContentCompressionResistancePriority(.required, for: .horizontal)
    iconImageView.setContentHuggingPriority(.required, for: .horizontal)
    iconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    iconImageView.contentMode = .center
    
    addSubview(iconImageView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    iconImageView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      iconImageView.topAnchor.constraint(equalTo: topAnchor),
      iconImageView.leftAnchor.constraint(equalTo: leftAnchor),
      iconImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
      iconImageView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
