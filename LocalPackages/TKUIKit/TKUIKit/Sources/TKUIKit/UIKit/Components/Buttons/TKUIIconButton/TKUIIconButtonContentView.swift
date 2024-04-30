import UIKit

public final class TKUIIconButtonContentView: UIView, ConfigurableView {
  private let iconImageView = UIImageView()
  private let titleLabel = UILabel()
  private let stackView = UIStackView()
  
  private var titleColor: UIColor = .Text.secondary
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Model {
    let image: UIImage
    let title: String
    
    public init(image: UIImage, title: String) {
      self.image = image
      self.title = title
    }
  }
  
  private var model = Model(image: UIImage(), title: "")
  
  public func configure(model: Model) {
    self.model = model
    iconImageView.image = model.image
    updateTitle()
  }
  
  public func setIconColor(_ color: UIColor) {
    iconImageView.tintColor = color
  }
  
  public func setTitleColor(_ color: UIColor) {
    self.titleColor = color
    updateTitle()
  }
}

private extension TKUIIconButtonContentView {
  func setup() {
    stackView.axis = .vertical
    stackView.spacing = 4
    
    iconImageView.contentMode = .center
    
    addSubview(stackView)
    stackView.addArrangedSubview(iconImageView)
    stackView.addArrangedSubview(titleLabel)
    
    setupConstraints()
    updateTitle()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
      stackView.leftAnchor.constraint(equalTo: leftAnchor).withPriority(.defaultHigh).withPriority(.defaultHigh),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16).withPriority(.defaultHigh),
      stackView.rightAnchor.constraint(equalTo: rightAnchor).withPriority(.defaultHigh)
    ])
  }
  
  func updateTitle() {
    titleLabel.attributedText = model.title
      .withTextStyle(
        .label3,
        color: titleColor,
        alignment: .center
      )
  }
}
