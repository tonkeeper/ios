import UIKit

public final class TKUIKeyboardButtonContentView: UIView, ConfigurableView {
  private let label = UILabel()
  private let imageView = UIImageView()
  private let stackView = UIStackView()
  
  private let textStyle: TKTextStyle
  
  public init(textStyle: TKTextStyle) {
    self.textStyle = textStyle
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public enum Model {
    case image(UIImage)
    case text(String)
  }
  
  public func configure(model: Model) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    switch model {
    case .image(let image):
      stackView.addArrangedSubview(imageView)
      imageView.image = image
    case .text(let text):
      stackView.addArrangedSubview(label)
      label.text = text
    }
  }
}

private extension TKUIKeyboardButtonContentView {
  func setup() {
    label.textColor = .Text.primary
    label.font = textStyle.font
    label.textAlignment = .center
    imageView.contentMode = .center
    imageView.tintColor = .Icon.primary
    addSubview(stackView)
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
      stackView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
