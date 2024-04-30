import UIKit

public final class TKUIButtonTitleIconContentView: UIView, ConfigurableView {
  
  let stackView = UIStackView()
  let titleLabel = UILabel()
  let iconImageView = UIImageView()
  
  public let textStyle: TKTextStyle
  public var foregroundColor: UIColor
  
  public init(textStyle: TKTextStyle,
              foregroundColor: UIColor) {
    self.textStyle = textStyle
    self.foregroundColor = foregroundColor
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Model {
    public struct Icon {
      public let icon: UIImage
      public let position: IconPosition
      public init(icon: UIImage, position: IconPosition) {
        self.icon = icon
        self.position = position
      }
    }
    public enum IconPosition {
      case left
      case right
    }
    public let title: String?
    public let icon: Icon?
    public init(title: String? = nil, icon: Icon? = nil) {
      self.title = title
      self.icon = icon
    }
  }
  
  public var model = Model(title: nil, icon: nil)
  
  public func configure(model: Model) {
    self.model = model
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    
    if model.title != nil {
      stackView.addArrangedSubview(titleLabel)
      updateTitle()
    }
    if let icon = model.icon {
      switch icon.position {
      case .left:
        stackView.insertArrangedSubview(iconImageView, at: 0)
      case .right:
        stackView.addArrangedSubview(iconImageView)
      }
      iconImageView.image = icon.icon
    }
  }
  
  public func setForegroundColor(_ color: UIColor) {
    self.foregroundColor = color
    updateTitle()
    iconImageView.tintColor = color
  }
}

private extension TKUIButtonTitleIconContentView {
  func setup() {
    stackView.alignment = .center
    stackView.axis = .horizontal
    stackView.spacing = 8
    
    setContentCompressionResistancePriority(.required, for: .horizontal)
    stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
    titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    iconImageView.contentMode = .center
    
    addSubview(stackView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
  
  func updateTitle() {
    titleLabel.attributedText = model.title?.withTextStyle(
      textStyle,
      color: foregroundColor,
      alignment: .center
    )
  }
}
